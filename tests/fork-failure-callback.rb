require 'tmpdir'
root=File.expand_path('..',__dir__)
header=File.read("#{root}/darwin/libc_private.h")
layout=header[/struct _libc_functions \{.*?\n\};/m] or abort 'layout missing'
source=File.read("#{root}/sys/fork.c")
source=source[source.index('extern pid_t __fork(void);')..]
Dir.mktmpdir('fork-failure-') do |dir|
  code=<<~C
    #define DARLING 1
    #define __private_extern__
    #include <sys/types.h>
    #include <sys/mman.h>
    #include <unistd.h>
    #include <stddef.h>
    #include <errno.h>
    #include <assert.h>
    #include <string.h>
    #include <stdio.h>
    #{layout}
    #define fork fixture_fork
    #{source}
    #undef fork
    static int result, prepares, parents, children, failures;
    pid_t __fork(void) { errno=EAGAIN; return result; }
    static void prepare(void) { ++prepares; }
    static void parent(void) { ++parents; errno=EIO; }
    static void child(void) { ++children; }
    static void failed(void) { ++failures; errno=EBADF; }
    int main(void) {
      struct _libc_functions funcs={.version=2,.atfork_prepare=prepare,
        .atfork_parent=parent,.atfork_child=child,.atfork_failed=failed};
      _libc_fork_init(&funcs);
      result=-1; assert(fixture_fork()==-1 && errno==EAGAIN);
      assert(prepares==1 && failures==1 && parents==0 && children==0);
      result=42; assert(fixture_fork()==42 && parents==1);
      result=0; assert(fixture_fork()==0 && children==1);
      funcs.atfork_failed=NULL; _libc_fork_init(&funcs);
      result=-1; assert(fixture_fork()==-1 && errno==EAGAIN && parents==2);
      long page=sysconf(_SC_PAGESIZE);
      char* region=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
      assert(region!=MAP_FAILED && mprotect(region+page,page,PROT_NONE)==0);
      size_t oldSize=offsetof(struct _libc_functions,atfork_failed);
      funcs.version=1; funcs.atfork_failed=failed;
      void* legacy=region+page-oldSize; memcpy(legacy,&funcs,oldSize);
      _libc_fork_init((const struct _libc_functions*)legacy);
      assert(fixture_fork()==-1 && errno==EAGAIN && parents==3 && failures==1);
      assert(munmap(region,page*2)==0);
      puts("PASS fork failure callback, errno preservation, success/child and guarded v1 ABI");
    }
  C
  File.write("#{dir}/test.c",code)
  system('clang','-Wall','-Wextra','-fsanitize=address,undefined',"#{dir}/test.c",'-o',"#{dir}/test",exception:true)
  system("#{dir}/test",exception:true)
end
