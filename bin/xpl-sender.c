#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <sys/utsname.h>
#include <string.h>
#include <strings.h>
#include <errno.h>

static char* usage =
  "Usage: xpl-send <ip-address> [type] [target] [class] [body-line] ...\n"
  "where:\n"
  "  ip-address should be the ip address to broadcast on (mandatory)\n"
  "  type is one of xpl-cmnd, xpl-stat or xpl-trig (optional)\n"
  "  target is of the either 'target=*' or a string like\n"
  "         'target=blah-dee.blah' (optional)\n"
  "  class is a schema class such as osd.basic, x10.basic, etc. (optional)\n"
  "  body-line is a line for the xPL message body such as 'command=clear'\n"
  "            or 'text=hello', etc. (zero or more)\n"
  "\n";

int main(int argc, char** argv)
{
  int s;
  int v = 1;
  int rc;
  size_t sent;
  struct sockaddr_in sa;
  char msg[2048] = "\0";
  char *dot;
  struct utsname utsname;
  char *hostname;
  int argoff = 1;

  if (argc < 2) {
    fprintf(stderr,usage);
    return(1);
  }

  argoff++;
  
  rc = uname(&utsname);
  hostname = strdup(utsname.nodename);
  dot = index(hostname, '.');
  if (dot) {
    *dot = '\0';
  }
 
  if (argc > argoff &&
      (0 == strncmp(argv[argoff], "xpl-cmnd", 9) ||
       0 == strncmp(argv[argoff], "xpl-stat", 9) ||
       0 == strncmp(argv[argoff], "xpl-trig", 9))) {
    strcat(msg, argv[argoff]);
    argoff++;
  } else {
    strcat(msg, "xpl-cmnd");
  }
  strcat(msg, "\n");

  strcat(msg, "{\nhop=1\nsource=bnz-send.");
  strcat(msg, hostname);
  strcat(msg, "\n");
  
  if (argc > argoff && (0 == strncmp(argv[argoff], "target=", 7))) {
    strcat(msg, argv[argoff]);
    argoff++;
  } else {
    strcat(msg, "target=*");
  }

  strcat(msg, "\n}\n");

  if (argc > argoff &&
      strlen(argv[argoff]) <= 17 &&
      index(argv[argoff], '.') != NULL) {
    strcat(msg, argv[argoff]);
    argoff++;
  } else {
    strcat(msg, "osd.basic");
  }
  strcat(msg, "\n{");
  while (argc > argoff) {
    strcat(msg, "\n");
    strcat(msg, argv[argoff]);
    argoff++;
  }
  strcat(msg, "\n}\n");
  
  s = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (!s) {
    perror("socket failed");
    return(1);
  }
  rc = setsockopt(3, SOL_SOCKET, SO_BROADCAST, &v, sizeof(v));
  if (rc) {
    perror("setsockopt SO_BROADCAST failed");
    return(1);
  }
  rc = setsockopt(3, SOL_SOCKET, SO_REUSEADDR, &v, sizeof(v));
  if (rc) {
    perror("setsockopt SO_REUSEADDR failed");
    return(1);
  }
  
  memset(&sa, 0, sizeof(sa));
  sa.sin_family = AF_INET;
  sa.sin_port = htons(3865);
  rc = inet_pton(AF_INET, argv[1], &(sa.sin_addr.s_addr));
  if (!rc) {
    printf("errno = %d\n", errno);
    perror("bad ip address? inet_pton failed");
    return(1);
  }

  rc = connect(s, (struct sockaddr *)&sa, sizeof(sa));
  if (rc) {
    printf("errno = %d\n", errno);
    perror("connect failed");
    return(1);
  }
  sent = send(s, msg, strlen(msg), 0);
  if (sent == -1) {
    perror("send failed");
    return(1);
  }
  return(0);
}
  
