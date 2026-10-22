#include <arpa/inet.h>
#include <asm-generic/socket.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdint.h>

int wayer_transfer_bind_test(int port){
    //POSIX socket creation (SOCK_STREAM  ensures TCP protocol)
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if(server_fd < 0){
        return -1;
    }

    //Allow immediate reuse of local address or port to avoid
    // "Address already in use" errors
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    //Setup the socket address structure
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;//bind to all available network interfaces
    address.sin_port = htons((uint16_t)port);

    if(bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0){
        close(server_fd);
        return -2;
    }

    close(server_fd);
    return 0;
}