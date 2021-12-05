#include <iostream>
#include <immintrin.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string>
#include <fstream>
#include <stdexcept>
#include <chrono>
#include <complex>
#include <numbers>

using namespace std;
using namespace std::chrono;

auto failedOpenStr = "Failed to open input file";
auto invalidSamplingRateStr = "Invalid sampling rate. Expected 44100";
auto invalidBitDepthStr = "Invalid bit depth. Expected 16.";
auto outFilePath = "output.bin";
char nullDelimiter[1] = { 0 };

//TODO clean up comments
//TODO remove unused globals
int windowSize = 4096;
int counter = 0;
float* s_signal_ptr;

complex<float>* fft_recurse(const float* signal, const unsigned signalLength)
{
	complex<float>* spectralComponents =
		new complex<float>[signalLength];

	const unsigned halfSignalLength = signalLength / 2;

	//cout << "check recurse termination";
	if (signalLength == 1)
	{
		spectralComponents[0] = signal[0];
		return spectralComponents;
	}

	//cout << "allocating even";
	float* evenSignal = new float[halfSignalLength];
	float* oddSignal = new float[halfSignalLength];

	//cout << "inintializing even and odd";
	for (unsigned i = 0; i < halfSignalLength; i++)
	{
		evenSignal[i] = signal[i * 2];
		oddSignal[i] = signal[i * 2 + 1];
	}

	//cout << "calling recurse";
	complex<float>* evenSpectralComponents = fft_recurse(evenSignal, halfSignalLength);
	complex<float>* oddSpectralComponents = fft_recurse(oddSignal, halfSignalLength);

	//cout << "looping";
	//TODO AVX?
	for (unsigned i = 0; i < halfSignalLength; i++)
	{
		//cout << "calculating";
		complex<float> oddOffsetSpectralComponent =
			polar<float>(1, -2 * numbers::pi * (i / static_cast<float>(signalLength))) *
			oddSpectralComponents[i];

		//cout << "assigning 1";
		spectralComponents[i] = evenSpectralComponents[i] + oddOffsetSpectralComponent;
		//cout << "assigning 2;";
		spectralComponents[halfSignalLength + i] = evenSpectralComponents[i] - oddOffsetSpectralComponent;
	}

	//cout << "cleaning up";
	delete[] evenSpectralComponents;
	delete[] oddSpectralComponents;

	delete[] evenSignal;
	delete[] oddSignal;

	return spectralComponents;
}

int main(int argc, char** argv)
{
	if (argc < 2) {
		cout << "No input file path argument provided." << endl;
		return -1;
	}

	string inFilePath = string(argv[1]);

	ifstream ifs;
	ifs.open(inFilePath.c_str(), ios::binary | ios::in);
	if (!ifs.is_open()) {
		cout << failedOpenStr << " " << inFilePath << endl;
		throw new exception(failedOpenStr);
	}

	char* headerBuffer = new char[44];
	ifs.read(headerBuffer, 44);

	int samplingRate = *(int*)(headerBuffer + 24);
	if (samplingRate != 44100)
	{
		cout << invalidSamplingRateStr << endl;
		throw new exception(invalidSamplingRateStr);
	}

	short bitDepth = *(short*)(headerBuffer + 34);
	if (bitDepth != 16)
	{
		cout << invalidBitDepthStr << endl;
		throw new exception(invalidBitDepthStr);
	}

	int dataBytes = *(int*)(headerBuffer + 40);

	long sampleCount = dataBytes / 2;
	float* signalPtr = new float[sampleCount];
	s_signal_ptr = signalPtr;

	for (int i = 0; i < sampleCount - 16; i += 16) {
		//convert into floats to get the signal buffer
		__m256i shortBuffer = {};
		//read 16 shorts
		ifs.read(reinterpret_cast<char*>(&shortBuffer), sizeof(__m256));

		//convert first 8 shorts to 8 ints
		__m256i lowerInts = _mm256_cvtepi16_epi32(*reinterpret_cast<__m128i*>(&shortBuffer));
		//convert remaining 8 shorts to 8 ints
		__m256i higherInts = _mm256_cvtepi16_epi32(*((__m128i*) & shortBuffer + 1));

		//convert lower 8 ints to floats
		__m256 lowerFloats = _mm256_cvtepi32_ps(lowerInts);
		//conver remaining 8 ints to floats
		__m256 higherFloats = _mm256_cvtepi32_ps(higherInts);

		//store lower 8 floats
		_mm256_store_ps(signalPtr + i, lowerFloats);

		//store remainig 8 floats
		_mm256_store_ps(signalPtr + i + 8, higherFloats);
	}

	ofstream ofs;
	ofs.open(outFilePath, ios::out | ios::beg | ios::binary);

	////write input file path
	//ofs.write(inFilePath.c_str(), inFilePath.length());
	//ofs.write(nullDelimiter, 1);

	////write current milliseconds
	//auto startMillis = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
	//ofs.write((char*)&startMillis, 8);
	//ofs.write(nullDelimiter, 1);

	////write signal
	//ofs.write((char*)signalPtr, sampleCount * 4);
	//ofs.write(nullDelimiter, 1);

	//pass signal buffer to fft
	for (int i = 0; i < sampleCount - windowSize; i += windowSize) {
		counter = i;

		complex<float>* specComps = fft_recurse(signalPtr + i, windowSize);
		
		if (specComps != nullptr) {
			ofs.write((char*)specComps, windowSize * sizeof(complex<float>));
		}
		//ofs.write(nullDelimiter, 1);
		/*for (int j = 0; j < windowSize/2; j++) {
			cout << abs(specComps[j]) << endl;
		}*/
		//delta f = fs / N; //(fs - sampling req, N - window size)
		delete[] specComps;
	}

	//free resources
	ofs.close();
	ifs.close();

	delete[] signalPtr;
	delete[] headerBuffer;
}