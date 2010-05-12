#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>


int main(void)
{
	char *filename = "/sys/power/state";
//	char *filename = "/sys/bus/pci/devices/0000:00:00.0/config";
//	char *filename = "/sys/devices/platform/dell_rbu/image_type";
	char buffer[100];
	int fd;
	int result;

	printf("filename = %s\n", filename);
	fd = open(filename, O_RDONLY | O_NONBLOCK);
	printf("fd = %d\n", fd);
	result = read(fd, buffer, 0);
	printf("result = %d\n", result);
	close(fd);
	return 0;
}

