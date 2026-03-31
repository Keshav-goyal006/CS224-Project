#include<stdio.h>

int main(){
    int n = 7;
    int a = 0;
    int b = 1;
    int next = 0;

    for (int i = 2; i <= n; i++)
    {
        next = a+b;
        a = b;
        b = next;
    }
    printf("%d",b);
    return b;
}