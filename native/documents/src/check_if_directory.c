#include <sys/stat.h>

int is_directory(const char *path){
    // "stat" is used to retriev filesystem information
    struct stat info;

    if(stat(path, &info) != 0){
        return 0; //Does not exist/ cannot be accessd
    }

    //"S_ISDIR()" checks whether a path refers to a directory
    return S_ISDIR(info.st_mode);
}