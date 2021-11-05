#include <iostream>
#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <filesystem>

using namespace std;

int main()
{
    // vector<string> msg = vector<string>{"Hello."};
    // for(const string& word : msg){
    //     cout << word << " ";
    // }
    // cout << endl;

    std::filesystem::path cwd = std::filesystem::current_path();

    ifstream in;
    in.open("output.wav");

    // int a;
    // asm("mov [a], RAX");
    // cout << a;

    bool open = in.is_open();
    char *arr = new char[101]{0};
    do
    {
        in.read(arr, 100);
        cout << string(arr);
    } while (!in.eof() || in.bad());

    delete[] arr;
}