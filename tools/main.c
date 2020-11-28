/*
 * Extraction tool that de-duplicates extracted files using FICLONE ioctl.
 *
 * Written by Ondrej Jirman <megous@megous.com> 2020, License: GPLv3
 */
#include <glib.h>
#include <stdbool.h>
#include <locale.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <archive.h>
#include <archive_entry.h>
#include <sys/ioctl.h>
#include <linux/fs.h>

#define MAX_FSIZE (200 << 20)

static GHashTable* ht;
static size_t total;
static size_t total_stored;
static int status;
G_LOCK_DEFINE_STATIC(shared);

static int copy_data(struct archive *ar, struct archive *aw)
{
	int64_t offset;
	const void *buff;
	size_t size;
	int r;

	for (;;) {
		r = archive_read_data_block(ar, &buff, &size, &offset);
		if (r == ARCHIVE_EOF)
			return (ARCHIVE_OK);
		if (r != ARCHIVE_OK)
			return (r);
		r = (int)archive_write_data_block(aw, buff, size, offset);
		if (r < ARCHIVE_WARN)
			r = ARCHIVE_WARN;
		if (r < ARCHIVE_OK) {
			archive_set_error(ar, archive_errno(aw),
			    "%s", archive_error_string(aw));
			return (r);
		}
	}
}

const char* excludes[] = {
	"./boot/",
	"./lib/firmware/",
	"./lib/modules/",
	"./usr/lib/firmware/",
	"./usr/lib/modules/",
//	"./usr/share/doc/",
//	"./usr/share/help/",
//	"./usr/share/man/",
//	"./usr/share/info/",
//	"./usr/share/locale/",
	"./usr/src/",
};

bool extract(const char* archive_path, const char* dst_prefix)
{
	struct archive_entry* entry;
	struct archive* a;
	struct archive* ad;
	uint8_t* buf;
	FILE* f;
	int ret;

	/* this need to be large enough to contain the most files in the
	 * archive, larger files will not be deduplicated */
	buf = g_malloc(MAX_FSIZE);

	ad = archive_write_disk_new();
	g_assert(ad != NULL);

	//archive_write_disk_set_standard_lookup(ad);

	int flags = ARCHIVE_EXTRACT_ACL |
             //ARCHIVE_EXTRACT_CLEAR_NOCHANGE_FFLAGS |
             ARCHIVE_EXTRACT_FFLAGS |
             ARCHIVE_EXTRACT_NO_OVERWRITE |
             ARCHIVE_EXTRACT_OWNER |
             ARCHIVE_EXTRACT_PERM |
             ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS |
             ARCHIVE_EXTRACT_SECURE_NODOTDOT |
             ARCHIVE_EXTRACT_SECURE_SYMLINKS |
             //ARCHIVE_EXTRACT_SPARSE |
             ARCHIVE_EXTRACT_TIME |
             ARCHIVE_EXTRACT_UNLINK |
             ARCHIVE_EXTRACT_XATTR;

	archive_write_disk_set_options(ad, flags);

	printf("Processing: %s <= %s\n", dst_prefix, archive_path);

	f = fopen(archive_path, "r");
	if (f == NULL) {
		printf("ERROR: Failed to open archive %s\n", archive_path);
		return false;
	}

	a = archive_read_new();

	//archive_read_support_format_all(a);
	archive_read_support_format_tar(a);
	archive_read_support_filter_zstd(a);

	ret = archive_read_open_FILE(a, f);
	if (ret) {
		printf("ERROR: Failed to open input file %s (%s)\n", archive_path, archive_error_string(a));
		goto err_close;
	}

next_entry:
	while (true) {
                char path[4096];
                char lpath[4096];

		ret = archive_read_next_header(a, &entry);
		if (ret == ARCHIVE_EOF)
			break;

		if (ret != ARCHIVE_OK) {
			printf("ERROR: Error reading archive %s\n", archive_error_string(a));
			goto err_close;
		}

		for (int i = 0; i < G_N_ELEMENTS(excludes); i++) {
			if (g_str_has_prefix(archive_entry_pathname(entry), excludes[i]))
				goto next_entry;
		}

		snprintf(path, sizeof path, "%s/%s", dst_prefix, archive_entry_pathname(entry));
		archive_entry_set_pathname(entry, path);

		if (archive_entry_hardlink(entry)) {
			snprintf(lpath, sizeof lpath, "%s/%s", dst_prefix, archive_entry_hardlink(entry));
			archive_entry_set_hardlink(entry, lpath);
		}

		size_t entry_size = archive_entry_size(entry);

		// update stats
		G_LOCK(shared);
		total += entry_size;
		G_UNLOCK(shared);

		if (archive_entry_size_is_set(entry) && entry_size > 0 && entry_size <= MAX_FSIZE) {
			/* files that fit in our dedup buffer will be processed
			 * by our dedup algorithm */

			ssize_t len = archive_read_data(a, buf, MAX_FSIZE);
			if (len < 0) {
				printf("ERROR: Error reading archive file %s: %s\n", path, archive_error_string(a));
				goto err_close;
			}

			// archive_read_data doesn't do padding for the last
			// segment of sparse file. do it here
			if (len < entry_size)
				memset(buf + len, 0, entry_size - len);

			gchar* csum = g_compute_checksum_for_data(G_CHECKSUM_SHA256, buf, entry_size);
			G_LOCK(shared);
			char* dup_path = g_hash_table_lookup(ht, csum);
			if (dup_path) {
				G_UNLOCK(shared);
				//printf("DUP: %s\n", dup_path);

                                archive_entry_set_size(entry, 0);

				ret = archive_write_header(ad, entry);
				if (ret != ARCHIVE_OK) {
					printf("ERROR: Failed to extract (header) %s: %s\n", path, archive_error_string(ad));
					goto err_close;
				}

				ret = archive_write_finish_entry(ad);
				if (ret != ARCHIVE_OK) {
					printf("ERROR: Failed to extract (finish) %s: %s\n", path, archive_error_string(ad));
					goto err_close;
				}

				int fd_src = open(dup_path, O_RDONLY);
				if (fd_src < 0) {
					printf("ERROR: Failed to clone data (src) %s: %s\n", path, strerror(errno));
					goto err_close;
				}

				int fd_dst = open(path, O_WRONLY);
				if (fd_dst < 0) {
					printf("ERROR: Failed to clone data (dst) %s: %s\n", path, strerror(errno));
					close(fd_src);
					goto err_close;
				}

				ret = ioctl(fd_dst, FICLONE, fd_src);
				close(fd_dst);
				close(fd_src);
				if (ret < 0) {
					printf("ERROR: Failed to clone data %s: %s\n", path, strerror(errno));
					goto err_close;
				}
			} else {
				total_stored += entry_size;
				g_hash_table_insert(ht, csum, g_strdup(path));
				G_UNLOCK(shared);

				ret = archive_write_header(ad, entry);
				if (ret != ARCHIVE_OK) {
					printf("ERROR: Failed to extract (header) %s: %s\n", path, archive_error_string(ad));
					goto err_close;
				}

				ret = (int)archive_write_data_block(ad, buf, entry_size, 0);
				if (ret < ARCHIVE_OK) {
					archive_write_finish_entry(ad);
					printf("ERROR: Failed to extract (data) %s: %s\n", path, archive_error_string(ad));
					goto err_close;
				}

				ret = archive_write_finish_entry(ad);
				if (ret != ARCHIVE_OK) {
					printf("ERROR: Failed to extract (finish) %s: %s\n", path, archive_error_string(ad));
					goto err_close;
				}
			}
		} else {
			ret = archive_write_header(ad, entry);
			if (ret != ARCHIVE_OK) {
				printf("ERROR: Failed to extract (header) %s: %s\n", path, archive_error_string(ad));
				goto err_close;
			}

			if (!archive_entry_size_is_set(entry) || archive_entry_size(entry) > 0) {
				ret = copy_data(a, ad);
				if (ret != ARCHIVE_OK) {
					archive_write_finish_entry(ad);
					printf("ERROR: Failed to extract (data) %s: %s\n", path, archive_error_string(ad));
					goto err_close;
				}
			}

			ret = archive_write_finish_entry(ad);
			if (ret != ARCHIVE_OK) {
				printf("ERROR: Failed to extract (finish) %s: %s\n", path, archive_error_string(ad));
				goto err_close;
			}
		}
	}

	g_free(buf);
	archive_read_free(a);
	archive_write_free(ad);
	fclose(f);
	return true;

err_close:
	g_free(buf);
	archive_read_free(a);
	archive_write_free(ad);
	fclose(f);
	return false;
}

static void extract_thread(gpointer data, gpointer user_data)
{
	gchar** vect = data;

	if (!extract(vect[1], vect[0])) {
		g_printerr("ERROR: Extraction failed for %s\n", vect[0]);

		G_LOCK(shared);
		status++;
		G_UNLOCK(shared);
	}
}

#ifndef PARALLEL
#define PARALLEL 16
#endif

int main(int argc, char* argv[])
{
	int ret, i;
	int status = 0;
	GError* local_err = NULL;

	setlocale(LC_ALL, "");

	ht = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

	GThreadPool* pool = g_thread_pool_new(extract_thread, NULL, PARALLEL, TRUE, &local_err);
	g_assert(local_err == NULL);

	for (i = 1; i < argc; i++) {
		gchar** vect = g_strsplit(argv[i], ":", 2);
		if (g_strv_length(vect) == 2) {
			g_thread_pool_push(pool, vect, NULL);
		} else {
			g_printerr("ERROR: Invalid spec: %s\n", argv[i]);

			G_LOCK(shared);
			status++;
			G_UNLOCK(shared);
			break;
		}
	}

	g_thread_pool_free(pool, FALSE, TRUE);

	printf("Statistics:\n");
	printf("  total  = %lu MiB\n", total / 1024 / 1024);
	printf("  stored = %lu MiB\n", total_stored / 1024 / 1024);

	return status;
}
