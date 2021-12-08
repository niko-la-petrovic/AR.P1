#include <iostream>
#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <filesystem>
#include <immintrin.h>
#include "avx2intrin.h"
#include <math.h>

using namespace std;

// __m256  _ZGVdN8v_cosf(__m256 x);

// int mm256_print_pd(__m256d x);
// int mm256_print_ps(__m256 x);

int main()
{
    // vector<string> msg = vector<string>{"Hello."};
    // for(const string& word : msg){
    //     cout << word << " ";
    // }
    // cout << endl;

    // std::filesystem::path cwd = std::filesystem::current_path();

    // ifstream in;
    // in.open("output.wav");

    // // int a;
    // // asm("mov [a], RAX");
    // // cout << a;

    // bool open = in.is_open();
    // char *arr = new char[101]{0};
    // do
    // {
    //     in.read(arr, 100);
    //     cout << string(arr);
    // } while (!in.eof() || in.bad());

    // delete[] arr;

    cout << "Assigning a" << endl;
    float a = 1.23;
    cout << "Assigning b and calculating cos" << endl;
    float b = cos(a);
    cout << b;

    // zf =_ZGVdN8v_cosf(xf);     printf("cosf(x)       ");
    // mm256_print_ps(zf);
}

// __attribute__ ((noinline)) int mm256_print_pd(__m256d x){
//     double vec_x[4];
//     _mm256_storeu_pd(vec_x,x);
//     printf("%12.8f %12.8f %12.8f %12.8f  \n", vec_x[3], vec_x[2], vec_x[1], vec_x[0]);
//     return 0;
// }


// __attribute__ ((noinline)) int mm256_print_ps(__m256 x){
//     float vec_x[8];
//     _mm256_storeu_ps(vec_x,x);
//     printf("%12.8f %12.8f %12.8f %12.8f %12.8f %12.8f %12.8f %12.8f \n", vec_x[7], vec_x[6], vec_x[5], vec_x[4],
//                      vec_x[3], vec_x[2], vec_x[1], vec_x[0]);
//     return 0;
// }