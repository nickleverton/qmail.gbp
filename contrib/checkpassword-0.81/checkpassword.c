#include <errno.h>
extern int errno;
extern char *crypt();
extern char *malloc();
extern char **environ;

int error_txtbsy =
#ifdef ETXTBSY
ETXTBSY;
#else
-4;
#endif

#include "prot.h"
#include <pwd.h>
static struct passwd *pw;
static char *stored;

#include "hasspnam.h"
#ifdef HASGETSPNAM
#include <shadow.h>
static struct spwd *spw;
#endif

#include "hasuserpw.h"
#ifdef HASUSERPW
#include <userpw.h>
static struct userpw *upw;
#endif

void doit(login)
char *login;
{
  pw = getpwnam(login);
  if (pw)
    stored = pw->pw_passwd;
  else {
    if (errno == error_txtbsy) _exit(111);
    _exit(1);
  }

#ifdef HASUSERPW
  upw = getuserpw(login);
  if (upw)
    stored = upw->upw_passwd;
  else
    if (errno == error_txtbsy) _exit(111);
#endif

#ifdef HASGETSPNAM
  spw = getspnam(login);
  if (spw)
    stored = spw->sp_pwdp;
  else
    if (errno == error_txtbsy) _exit(111);
#endif
}

char *str1e2(name,value) char *name; char *value;
{
  char *nv;
  nv = malloc(strlen(name) + strlen(value) + 2);
  if (!nv) _exit(111);
  strcpy(nv,name);
  strcat(nv,"=");
  strcat(nv,value);
  return nv;
}

char up[513];
int uplen;

void main(argc,argv)
int argc;
char **argv;
{
  char *login;
  char *password;
  char *encrypted;
  int r;
  int i;
  char **newenv;
  int numenv;
 
  if (!argv[1]) _exit(2);
 
  uplen = 0;
  for (;;) {
    do
      r = read(3,up + uplen,sizeof(up) - uplen);
    while ((r == -1) && (errno == EINTR));
    if (r == -1) _exit(111);
    if (r == 0) break;
    uplen += r;
    if (uplen >= sizeof(up)) _exit(1);
  }

  close(3);

  i = 0;
  login = up + i;
  while (up[i++]) if (i == uplen) _exit(2);
  password = up + i;
  if (i == uplen) _exit(2);
  while (up[i++]) if (i == uplen) _exit(2);

  doit(login);
 
  encrypted = crypt(password,stored);
 
  for (i = 0;i < sizeof(up);++i) up[i] = 0;
 
  if (!*stored || strcmp(encrypted,stored)) _exit(1);
 
  if (prot_gid((int) pw->pw_gid) == -1) _exit(1);
  if (prot_uid((int) pw->pw_uid) == -1) _exit(1);
  if (chdir(pw->pw_dir) == -1) _exit(111);
 
  numenv = 0;
  while (environ[numenv]) ++numenv;
  newenv = (char **) malloc((numenv + 4) * sizeof(char *));
  if (!newenv) _exit(111);
  for (i = 0;i < numenv;++i) newenv[i] = environ[i];
  newenv[numenv++] = str1e2("USER",pw->pw_name);
  newenv[numenv++] = str1e2("HOME",pw->pw_dir);
  newenv[numenv++] = str1e2("SHELL",pw->pw_shell);
  newenv[numenv] = 0;
  environ = newenv;
 
  execvp(argv[1],argv + 1);
  _exit(111);
}
