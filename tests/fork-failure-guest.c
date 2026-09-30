// Run in a disposable Darling environment where public fork returns ENOSYS.
// This checks the failure-cleanup path, not successful process creation.
#include <unistd.h>
#include <pthread.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <sys/wait.h>
static int prepares, parents, children;
static void prepare(void) { ++prepares; }
static void parent(void) { ++parents; errno=EIO; }
static void child(void) { ++children; }
int main(void) {
    assert(pthread_atfork(prepare,parent,child)==0);
    for (int i=0;i<3;++i) {
        errno=0;
        pid_t pid=fork();
        int error=errno;
        if (pid==0) _exit(77);
        if (pid!=-1 || error!=ENOSYS) {
            if (pid>0) {
                int status;
                while (waitpid(pid,&status,0)<0 && errno==EINTR) {}
            }
            fprintf(stderr,"fixture requires failing ENOSYS fork; pid=%d errno=%d\n",pid,error);
            return 77;
        }
        assert(prepares==i+1 && parents==i+1 && children==0);
        void* allocation=malloc(4096); assert(allocation); free(allocation);
    }
    puts("PASS repeated failed fork preserves errno and runs parent cleanup without waiting");
}
