/****************************************************************************
 * apps/examples/mount/mount_main.c
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.  The
 * ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 ****************************************************************************/

/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/statfs.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <debug.h>

#include "mount.h"
#include <nuttx/mmcsd.h> 

/****************************************************************************
 * Pre-processor Definitions
 ****************************************************************************/

#define TEST_USE_STAT         1
#define TEST_SHOW_DIRECTORIES 1
#define TEST_USE_STATFS       1

/****************************************************************************
 * Private Types
 ****************************************************************************/

/****************************************************************************
 * Private Data
 ****************************************************************************/

static const char g_mntdir[]         = "/mnt";
static const char g_target[]         = "/mnt/fs";
static const char g_filesystemtype[] = "vfat";

static const char g_testdir1[]       = "/mnt/fs/TestDir";
static const char g_testdir2[]       = "/mnt/fs/NewDir1";
static const char g_testdir3[]       = "/mnt/fs/NewDir2";
static const char g_testdir4[]       = "/mnt/fs/NewDir3";
#ifdef CONFIG_EXAMPLES_MOUNT_DEVNAME
static const char g_testfile1[]      = "/mnt/fs/TestDir/TestFile.txt";
#endif
static const char g_testdiri[]      = "/mnt/fs/i";
static const char g_testdirj[]      = "/mnt/fs/j";
static const char g_testfilej[]      = "/mnt/fs/j/j.txt";
static const char g_testfilel[]      = "/mnt/fs/WrTest1.txt";
static const char g_testfile2[]      = "/mnt/fs/TestDir/WrTest1.txt";
static const char g_testfile3[]      = "/mnt/fs/NewDir1/WrTest2.txt";
static const char g_testfile4[]      = "/mnt/fs/NewDir3/Renamed.txt";
static const char g_testmsg[]        = "This is a write test";

static int        g_nerrors          = 0;

static char       g_namebuffer[256];

/****************************************************************************
 * Public Data
 ****************************************************************************/

       const char g_source[]         = MOUNT_DEVNAME;

/****************************************************************************
 * Private Functions
 ****************************************************************************/

#ifdef TEST_USE_STAT
static void show_stat(const char *path, struct stat *ps)
{
  _info("%s stat:\n", path);
  _info("\tmode        : %08x\n", ps->st_mode);

  if (S_ISREG(ps->st_mode))
    {
      _info("\ttype        : File\n");
    }
  else if (S_ISDIR(ps->st_mode))
    {
      _info("\ttype        : Directory\n");
    }
  else if (S_ISCHR(ps->st_mode))
    {
      _info("\ttype        : Character driver\n");
    }
  else if (S_ISBLK(ps->st_mode))
    {
      _info("\ttype        : Block driver\n");
    }
  else if (S_ISMQ(ps->st_mode))
    {
      _info("\ttype        : Message queue\n");
    }
  else if (S_ISSEM(ps->st_mode))
    {
      _info("\ttype        : Named semaphore\n");
    }
  else if (S_ISSHM(ps->st_mode))
    {
      _info("\ttype        : Shared memory\n");
    }
  else if (S_ISSOCK(ps->st_mode))
    {
      _info("\ttype        : Socket\n");
    }
  else if (S_ISMTD(ps->st_mode))
    {
      _info("\ttype        : Named MTD driver\n");
    }
  else if (S_ISLNK(ps->st_mode))
    {
      _info("\ttype        : Symbolic link\n");
    }
  else
    {
      _info("\ttype        : Unknown\n");
    }

  _info("\tsize        : %jd (bytes)\n", (intmax_t)ps->st_size);
  _info("\tblock size  : %d (bytes)\n",  ps->st_blksize);
  _info("\tsize        : %ju (blocks)\n", (uintmax_t)ps->st_blocks);
  _info("\taccess time : %ju\n", (uintmax_t)ps->st_atime);
  _info("\tmodify time : %ju\n", (uintmax_t)ps->st_mtime);
  _info("\tchange time : %ju\n", (uintmax_t)ps->st_ctime);
}
#endif

/****************************************************************************
 * Name: show_statfs
 ****************************************************************************/

#ifdef TEST_USE_STATFS
static void show_statfs(const char *path)
{
  struct statfs buf;
  int ret;

  /* Try stat() against a file or directory.  It should fail with
   * expectederror
   */

  _info("show_statfs: Try statfs(%s)\n", path);
  ret = statfs(path, &buf);
  if (ret == 0)
    {
      _info("show_statfs: statfs(%s) succeeded\n", path);
      _info("\tFS Type           : %0" PRIx32 "\n", buf.f_type);
      _info("\tBlock size        : %zd\n", buf.f_bsize);
      _info("\tNumber of blocks  : %jd\n", (intmax_t)buf.f_blocks);
      _info("\tFree blocks       : %jd\n", (intmax_t)buf.f_bfree);
      _info("\tFree user blocks  : %jd\n", (intmax_t)buf.f_bavail);
      _info("\tNumber file nodes : %jd\n", (intmax_t)buf.f_files);
      _info("\tFree file nodes   : %jd\n", (intmax_t)buf.f_ffree);
      _info("\tFile name length  : %zd\n", buf.f_namelen);
    }
  else
    {
      _info("show_statfs: ERROR statfs(%s) failed with errno=%d\n",
             path, errno);
      g_nerrors++;
    }
}
#else
#  define show_statfs(p)
#endif

/****************************************************************************
 * Name: show_directories
 ****************************************************************************/

#ifdef TEST_SHOW_DIRECTORIES
static void show_directories(const char *path, int indent)
{
  DIR *dirp;
  struct dirent *direntry;
  int i;

  dirp = opendir(path);
  if (!dirp)
    {
      _info("show_directories: ERROR opendir(\"%s\") with errno=%d\n",
             path, errno);
      g_nerrors++;
      return;
    }

  for (direntry = readdir(dirp); direntry; direntry = readdir(dirp))
    {
      for (i = 0; i < 2*indent; i++)
        {
          putchar(' ');
        }

      if (DIRENT_ISDIRECTORY(direntry->d_type))
        {
          char *subdir;
          _info("%s/\n", direntry->d_name);
          snprintf(g_namebuffer, sizeof(g_namebuffer),
                   "%s/%s", path, direntry->d_name);
          subdir = strdup(g_namebuffer);
          show_directories(subdir, indent + 1);
          free(subdir);
        }
      else
        {
          _info("%s\n", direntry->d_name);
        }
    }

  closedir(dirp);
}
#else
#  define show_directories(p,i)
#endif

/****************************************************************************
 * Name: fail_read_open
 ****************************************************************************/

#ifdef CONFIG_EXAMPLES_MOUNT_DEVNAME
static void fail_read_open(const char *path, int expectederror)
{
  int fd;

  _info("fail_read_open: Try open(%s) for reading\n", path);

  fd = open(path, O_RDONLY);
  if (fd >= 0)
    {
      _info("fail_read_open: ERROR open(%s) succeeded\n", path);
      g_nerrors++;
      close(fd);
    }
  else if (errno != expectederror)
    {
      _info("fail_read_open: ERROR open(%s) with errno=%d(expect %d)\n",
             path, errno, expectederror);
      g_nerrors++;
    }
}
#endif

/****************************************************************************
 * Name: read_test_file
 ****************************************************************************/

static void read_test_file(const char *path)
{
  char buffer[128];
  int  nbytes;
  int  fd;

  /* Read a test file that is already on the test file system image */

  _info("read_test_file: opening %s for reading\n", path);

  fd = open(path, O_RDONLY);
  if (fd < 0)
    {
      _info("read_test_file: ERROR failed to open %s, errno=%d\n",
             path, errno);
      g_nerrors++;
    }
  else
    {
      memset(buffer, 0, 128);
      nbytes = read(fd, buffer, 128);
      if (nbytes < 0)
        {
          _info("read_test_file: ERROR failed to read from %s, errno=%d\n",
                 path, errno);
          g_nerrors++;
        }
      else
        {
          buffer[127] = '\0';
          _info("read_test_file: Read \"%s\" from %s\n", buffer, path);
        }

      close(fd);
    }
}

/****************************************************************************
 * Name: write_test_file
 ****************************************************************************/

static void write_test_file(const char *path)
{
  int fd;

  /* Write a test file into a pre-existing file on the test file system */

  _info("write_test_file: opening %s for writing\n", path);

  fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd < 0)
    {
      _info("write_test_file: ERROR to open %s for writing, errno=%d\n",
             path, errno);
      g_nerrors++;
    }
  else
    {
      int nbytes = write(fd, g_testmsg, strlen(g_testmsg));
      if (nbytes < 0)
        {
          _info("write_test_file: ERROR failed to write to %s, errno=%d\n",
                 path, errno);
          g_nerrors++;
        }
      else
        {
          _info("write_test_file: wrote %d bytes to %s\n", nbytes, path);
        }

      close(fd);
    }
}

/****************************************************************************
 * Name: fail_mkdir
 ****************************************************************************/

static void fail_mkdir(const char *path, int expectederror)
{
  int ret;

  /* Try mkdir() against a file or directory.  It should fail with
   * expectederror
   */

  _info("fail_mkdir: Try mkdir(%s)\n", path);

  ret = mkdir(path, 0666);
  if (ret == 0)
    {
      _info("fail_mkdir: ERROR mkdir(%s) succeeded\n", path);
      g_nerrors++;
    }
  else if (errno != expectederror)
    {
      _info("fail_mkdir: ERROR mkdir(%s) with errno=%d(expect %d)\n",
             path, errno, expectederror);
      g_nerrors++;
    }
}

/****************************************************************************
 * Name: succeed_mkdir
 ****************************************************************************/

static void succeed_mkdir(const char *path)
{
  int ret;

  _info("succeed_mkdir: Try mkdir(%s)\n", path);

  ret = mkdir(path, 0666);
  if (ret != 0)
    {
      _info("succeed_mkdir: ERROR mkdir(%s) failed with errno=%d\n",
             path, errno);
      g_nerrors++;
    }
}

/****************************************************************************
 * Name: fail_rmdir
 ****************************************************************************/

static void fail_rmdir(const char *path, int expectederror)
{
  int ret;

  /* Try rmdir() against a file or directory.  It should fail with
   * expectederror
   */

  _info("fail_rmdir: Try rmdir(%s)\n", path);

  ret = rmdir(path);
  if (ret == 0)
    {
      _info("fail_rmdir: ERROR rmdir(%s) succeeded\n", path);
      g_nerrors++;
    }
  else if (errno != expectederror)
    {
      _info("fail_rmdir: ERROR rmdir(%s) with errno=%d(expect %d)\n",
             path, errno, expectederror);
      g_nerrors++;
    }
}

/****************************************************************************
 * Name: succeed_rmdir
 ****************************************************************************/

static void succeed_rmdir(const char *path)
{
  int ret;

  _info("succeed_rmdir: Try rmdir(%s)\n", path);

  ret = rmdir(path);
  if (ret != 0)
    {
      _info("succeed_rmdir: ERROR rmdir(%s) failed with errno=%d\n",
             path, errno);
      g_nerrors++;
    }
}

/****************************************************************************
 * Name: fail_unlink
 ****************************************************************************/

static void fail_unlink(const char *path, int expectederror)
{
  int ret;

  /* Try unlink() against a file or directory.  It should fail with
   * expectederror
   */

  _info("fail_unlink: Try unlink(%s)\n", path);

  ret = unlink(path);
  if (ret == 0)
    {
      _info("fail_unlink: ERROR unlink(%s) succeeded\n", path);
      g_nerrors++;
    }
  else if (errno != expectederror)
    {
      _info("fail_unlink: ERROR unlink(%s) with errno=%d(expect %d)\n",
             path, errno, expectederror);
      g_nerrors++;
    }
}

/****************************************************************************
 * Name: succeed_unlink
 ****************************************************************************/

static void succeed_unlink(const char *path)
{
  int ret;

  /* Try unlink() against the test file.  It should succeed. */

  _info("succeed_unlink: Try unlink(%s)\n", path);

  ret = unlink(path);
  if (ret != 0)
    {
      _info("succeed_unlink: ERROR unlink(%s) failed with errno=%d\n",
             path, errno);
      g_nerrors++;
    } else {
	    _info("succeed_unlink: success\n");
    }
}

/****************************************************************************
 * Name: fail_rename
 ****************************************************************************/

static void fail_rename(const char *oldpath, const char *newpath,
                        int expectederror)
{
  int ret;

  /* Try rename() against a file or directory.  It should fail with
   * expectederror
   */

  _info("fail_rename: Try rename(%s->%s)\n", oldpath, newpath);

  ret = rename(oldpath, newpath);
  if (ret == 0)
    {
      _info("fail_rename: ERROR rename(%s->%s) succeeded\n",
             oldpath, newpath);
      g_nerrors++;
    }
  else if (errno != expectederror)
    {
      _info("fail_rename: ERROR rename(%s->%s) with errno=%d(expect %d)\n",
             oldpath, newpath, errno, expectederror);
      g_nerrors++;
    }
}

/****************************************************************************
 * Name: succeed_rename
 ****************************************************************************/

static void succeed_rename(const char *oldpath, const char *newpath)
{
  int ret;

  _info("succeed_rename: Try rename(%s->%s)\n", oldpath, newpath);

  ret = rename(oldpath, newpath);
  if (ret != 0)
    {
      _info("succeed_rename: ERROR rename(%s->%s) failed with errno=%d\n",
             oldpath, newpath, errno);
      g_nerrors++;
    }
}

/****************************************************************************
 * Name: fail_stat
 ****************************************************************************/

#ifdef TEST_USE_STAT
static void fail_stat(const char *path, int expectederror)
{
  struct stat buf;
  int ret;

  /* Try stat() against a file or directory.  It should fail with
   * expectederror
   */

  _info("fail_stat: Try stat(%s)\n", path);

  ret = stat(path, &buf);
  if (ret == 0)
    {
      _info("fail_stat: ERROR stat(%s) succeeded\n", path);
      show_stat(path, &buf);
      g_nerrors++;
    }
  else if (errno != expectederror)
    {
      _info("fail_stat: ERROR stat(%s) failed with errno=%d(expected %d)\n",
             path, errno, expectederror);
      g_nerrors++;
    }
}
#else
#  define fail_stat(p,e);
#endif

/****************************************************************************
 * Name: succeed_stat
 ****************************************************************************/

#ifdef TEST_USE_STAT
static void succeed_stat(const char *path)
{
  struct stat buf;
  int ret;

  _info("succeed_stat: Try stat(%s)\n", path);

  ret = stat(path, &buf);
  if (ret != 0)
    {
      _info("succeed_stat: ERROR stat(%s) failed with errno=%d\n",
             path, errno);
      g_nerrors++;
    }
  else
    {
      _info("succeed_stat: stat(%s) succeeded\n", path);
      show_stat(path, &buf);
    }
}
#else
#define succeed_stat(p)
#endif

/****************************************************************************
 * Public Functions
 ****************************************************************************/

/****************************************************************************
 * Name: mount_main
 ****************************************************************************/

int main(int argc, FAR char *argv[])
{
  int ret;

#ifndef CONFIG_EXAMPLES_MOUNT_DEVNAME
  /* Create a RAM disk for the test */

  ret = create_ramdisk();
  if (ret < 0)
    {
      _info("mount_main: ERROR failed to create RAM disk\n");
      return 1;
    } else
      _info("mount_main: created RAM disk\n");
#endif

  mmcsd_spislotinitialize(0, 0, 0);

  /* Mount the test file system (see arch/sim/src/up_deviceimage.c */

  _info("mount_main: mounting %s filesystem at target=%s with source=%s\n",
         g_filesystemtype, g_target, g_source);

  ret = mount(g_source, g_target, g_filesystemtype, 0, NULL);
  _info("mount_main: mount() returned %d\n", ret);

  if (ret < 0) {
      _info("mount errno=%d\n", errno);
  } else if (ret == 0)
    {
      //show_statfs(g_mntdir);
      //show_statfs(g_target);
#if 0
      succeed_mkdir(g_testdirj);
	  write_test_file(g_testfilej);
	  succeed_rename(g_testdirj, g_testdiri);
      show_directories("", 0);
#endif
      	write_test_file(g_testfilel);
		//show_directories("", 0);
      	//succeed_stat(g_testfilel);
      	//show_statfs(g_testfilel);
		read_test_file(g_testfilel);
		succeed_unlink(g_testfilel);
//#if 0
#ifdef CONFIG_EXAMPLES_MOUNT_DEVNAME
      succeed_mkdir(g_testdir1);
      show_directories("", 0);
      succeed_stat(g_testdir1);
      show_statfs(g_testdir1);

      /* Read a test file that is already on the test file system image */

	  write_test_file(g_testfile1);
      show_directories("", 0);
      succeed_stat(g_testfile1);
      show_statfs(g_testfile1);
      read_test_file(g_testfile1);
	  //succeed_unlink(g_testfile1);
#else
      /* Create the test directory that would have been on the canned
       * filesystem
       */

      succeed_mkdir(g_testdir1);
      show_directories("", 0);
      succeed_stat(g_testdir1);
      show_statfs(g_testdir1);
#endif

      /* Write a test file into a pre-existing directory on the test file
       * system
       */

      fail_stat(g_testfile2, ENOENT);
      write_test_file(g_testfile2);
      show_directories("", 0);
      succeed_stat(g_testfile2);
      show_statfs(g_testfile2);

      /* Read the file that we just wrote */

      read_test_file(g_testfile2);

      /* Try rmdir() against a file on the directory.  It should fail with
       * ENOTDIR
       */
#ifdef CONFIG_EXAMPLES_MOUNT_DEVNAME
      fail_rmdir(g_testfile1, ENOTDIR);
#endif

      /* Try rmdir() against the test directory.  It should fail with
       * ENOTEMPTY
       */

      fail_rmdir(g_testdir1, ENOTEMPTY);

      /* Try unlink() against the test directory.  It should fail with
       * EISDIR
       */

      fail_unlink(g_testdir1, EISDIR);

      /* Try unlink() against the test file1.  It should succeed. */
#ifdef CONFIG_EXAMPLES_MOUNT_DEVNAME
      succeed_unlink(g_testfile1);
      fail_stat(g_testfile1, ENOENT);
      show_directories("", 0);
#endif

      /* Attempt to open testfile1 should fail with ENOENT */
#ifdef CONFIG_EXAMPLES_MOUNT_DEVNAME
      fail_read_open(g_testfile1, ENOENT);
#endif
      /* Try rmdir() against the test directory.  It should still fail with
       * ENOTEMPTY
       */

      fail_rmdir(g_testdir1, ENOTEMPTY);

      /* Try mkdir() against the test file2.  It should fail with EEXIST. */

      fail_mkdir(g_testfile2, EEXIST);

      /* Try unlink() against the test file2.  It should succeed. */

      succeed_unlink(g_testfile2);
      show_directories("", 0);
      fail_stat(g_testfile2, ENOENT);

      /* Try mkdir() against the test dir1.  It should fail with EEXIST. */

      fail_mkdir(g_testdir1, EEXIST);

      /* Try rmdir() against the test directory.  mkdir should now succeed. */

      succeed_rmdir(g_testdir1);
      show_directories("", 0);
      fail_stat(g_testdir1, ENOENT);

      /* Try mkdir() against the test dir2.  It should succeed */

      succeed_mkdir(g_testdir2);
      show_directories("", 0);
      succeed_stat(g_testdir2);
      show_statfs(g_testdir2);

      /* Try mkdir() against the test dir2.  It should fail with EXIST */

      fail_mkdir(g_testdir2, EEXIST);


      /* Write a test file into a new directory on the test file system */

      fail_stat(g_testfile3, ENOENT);
      write_test_file(g_testfile3);
      show_directories("", 0);
      succeed_stat(g_testfile3);
      show_statfs(g_testfile3);

      /* Read the file that we just wrote */

      read_test_file(g_testfile3);

      /* Use mkdir() to create test dir3.  It should succeed */

      fail_stat(g_testdir3, ENOENT);
      succeed_mkdir(g_testdir3);
      show_directories("", 0);
      succeed_stat(g_testdir3);
      show_statfs(g_testdir3);

      /* Try rename() on the root directory. Should fail with EXDEV */

      fail_rename(g_mntdir, g_testdir4, EXDEV);

      /* Try rename() to an existing directory.  Should fail with ENOENT */

      fail_rename(g_testdir4, g_testdir3, ENOENT);

      /* Try rename() to a non-existing directory.  Should succeed */
	  _info("Try rename() to a non-existing directory.  Should succeed\n");
      fail_stat(g_testdir4, ENOENT);
      succeed_rename(g_testdir3, g_testdir4);
      show_directories("", 0);
      fail_stat(g_testdir3, ENOENT);
      succeed_stat(g_testdir4);
      show_statfs(g_testdir4);

      /* Try rename() of file.  Should work. */
	  _info("Try rename() of file.  Should work.\n");
      fail_stat(g_testfile4, ENOENT);
      succeed_rename(g_testfile3, g_testfile4);
      show_directories("", 0);
      fail_stat(g_testfile3, ENOENT);
      succeed_stat(g_testfile4);
      show_statfs(g_testfile4);

      /* Make sure that we can still read the renamed file */

      read_test_file(g_testfile4);

	  //show_directories("", 0);
//#endif

      /* Unmount the file system */

      _info("mount_main: Try unmount(%s)\n", g_target);

      ret = umount(g_target);
      if (ret != 0)
        {
          _info("mount_main: ERROR umount() failed, errno %d\n", errno);
          g_nerrors++;
        }

      _info("mount_main: %d errors reported\n", g_nerrors);
    }

  fflush(stdout);
  return 0;
}
