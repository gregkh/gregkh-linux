#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/select.h>

void fail(const char *msg)
{
  perror(msg);
  exit(EXIT_FAILURE);
}

int
main(int argc, char **argv)
{
  if (argc != 2) {
    fprintf(stderr, "Pass a file name as argument.\n");
    exit(EXIT_FAILURE);
  }

  const char *filename = argv[1];
  int fd = open(filename, O_RDONLY | O_NONBLOCK);
  
  if (fd == -1) fail("open");

  fd_set rfds;
  struct timeval tv;
  int retval;
  char buf[512];

  /* Add the file descriptor */
  FD_ZERO(&rfds);
  FD_SET(fd, &rfds);

  assert(FD_ISSET(fd, &rfds));

  while (1) {
    /* Wait max five seconds. */
    tv.tv_sec = 5;
    tv.tv_usec = 0;
    
    retval = select(fd+1, &rfds, NULL, NULL, &tv);
    
    switch (retval) {
    case -1: fail("select");	/* Does not return. */
    case  0: printf("Timeout...\n"); break;
    default:
      retval = read(fd, buf, sizeof(buf));
      printf("Read %d bytes.\n", retval);

      if (retval == 0) {
	printf("EOF\n");
	return 0;
      }
    }
  }

  return 0;
}
