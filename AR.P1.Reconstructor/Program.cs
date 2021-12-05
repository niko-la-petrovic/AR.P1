using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace AR.P1.Reconstructor
{
    public struct Complex
    {
        public float Real { get; set; }
        public float Imaginary { get; set; }
        public float Magnitude => (float)Math.Sqrt(Math.Pow(Real, 2) + Math.Pow(Imaginary, 2));
    }

    class Program
    {
        public const double SamplingRate = 44100.0;
        public const int WindowSize = 4096;
        public const string OutPath = "output.csv";

        unsafe static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                Console.WriteLine("Specify an input file.");
                return;
            }

            string inputFilePath = args[0];

            var fileInfo = new FileInfo(inputFilePath);
            var fileLength = fileInfo.Length;
            if (fileLength % 8 != 0)
                throw new InvalidOperationException(nameof(fileLength));


            using var fs = new FileStream(inputFilePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            using var reader = new BinaryReader(fs);

            var allBytes = reader.ReadBytes((int)fileLength);

            fs.Seek(0, SeekOrigin.Begin);

            List<Complex> specComps = new();
            for (int i = 0; i < fileLength / 8; i++)
            {
                float real = reader.ReadSingle();
                float imaginary = reader.ReadSingle();
                Complex specComp = new() { Real = real, Imaginary = imaginary };
                specComps.Add(specComp);
            }

            using var ofs = new FileStream(OutPath, FileMode.Create, FileAccess.ReadWrite, FileShare.Read);
            using var writer = new StreamWriter(ofs);
            writer.WriteLine($"Index,Frequency,Magnitude");

            var windowedComps = specComps.Take(WindowSize).ToList();
            var maxMagnitude = windowedComps.Take(WindowSize / 2).Max(c => c.Magnitude);
            Console.WriteLine($"Max magnitude in first half-window: {maxMagnitude}");
            Console.WriteLine("Max magnitude in first window at:");
            for (int i = 0; i < windowedComps.Count / 2; i++)
            {
                var specComp = windowedComps[i];
                if (specComp.Magnitude == maxMagnitude)
                    Console.WriteLine($"{i}: {i * SamplingRate / WindowSize}");
                writer.WriteLine($"{i},{i * SamplingRate / WindowSize},{specComp.Magnitude}");
            }
        }
    }
}
