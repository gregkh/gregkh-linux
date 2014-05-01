FROM lf/herlo/fedora:20
MAINTAINER Clint Savage <herlo@linuxfoundation.org>

ADD /root/test_stable/run_test.sh /root/run_test.sh

RUN chmod +x /root/run_test.sh

RUN nohup bash -x ./run_test.sh > /root/output_log 2>&1 &

git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

