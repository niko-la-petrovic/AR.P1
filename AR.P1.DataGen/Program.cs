using CommandLine;
using System;
using System.IO;
using System.Text;

namespace AR.P1.DataGen
{
    public class Program
    {
        private static byte[] byteArray = new byte[1];
        private static byte[] shortArray = new byte[2];
        private static byte[] triArray = new byte[3];
        private static byte[] intArray = new byte[4];

        public class Options
        {
            [Option('v', "verbose", Required = false, HelpText = "Set the output to verbose.")]
            public bool Verbose { get; set; }
            [Option('r', "sampling-rate", Required = false, HelpText = "Set the sampling rate.", Default = 44100)]
            public int SamplingRate { get; set; }
            [Option('l', "length", Required = false, HelpText = "Set the length of output in seconds.", Default = 1)]
            public int SecondLength { get; set; }
            [Option('s', "shape", Required = false, HelpText = "Set the waveform shape.", Default = WaveformShape.Sine)]
            public WaveformShape WaveformShape { get; set; }
            [Option('o', "output", Required = false, HelpText = "Set the output file.", Default = "output.wav")]
            public string OutputFilePath { get; set; }
            [Option('f', "frequency", Required = false, HelpText = "Set the frequency of signal.", Default = 800)]
            public double Frequency { get; set; }
            [Option('b', "bit-depth", Required = false, HelpText = "Set the bit depth.", Default = 16)]
            public int BitDepth { get; set; }
        }

        static void Main(string[] args)
        {
            var parser = Parser.Default;
            var parserResult = parser
                .ParseArguments<Options>(args);

            parserResult.WithParsed(o =>
            {
                GenerateData(o.MapToOptions());
            });
            parserResult.WithNotParsed(o =>
            {
                Console.WriteLine("Use --help.");
            });
        }

        protected static void GenerateData(DataGenOptions dataGenOptions)
        {
            using var fileStream = File.OpenWrite(dataGenOptions.OutputFilePath);
            using var bufferedStream = new BufferedStream(fileStream);
            using var binaryStream = new BinaryWriter(bufferedStream);

            Func<double, double> waveform = SelectWaveform(dataGenOptions);

            WriteWavHeader(dataGenOptions, binaryStream);
            WriteData(dataGenOptions, binaryStream, waveform);
        }

        public static void WriteData(DataGenOptions dataGenOptions, BinaryWriter binaryStream, Func<double, double> waveform)
        {
            double t = 0;
            Func<double, byte[]> getBytesToWrite = GetBytesToWrite(dataGenOptions.ByteDepth);

            for (long i = 0; i < dataGenOptions.SampleCount; i++)
            {
                var amplitude = Math.Pow(2, dataGenOptions.BitDepth - 1) - 1;
                var displacement = amplitude * waveform(t);
                var arrToWrite = getBytesToWrite(displacement);

                binaryStream.Write(arrToWrite);
                t += dataGenOptions.SampleLength;
            }
        }

        public unsafe static Func<double, byte[]> GetBytesToWrite(int byteDepth)
        {
            switch (byteDepth)
            {
                case 1:
                    return v =>
                    {
                        fixed (byte* array = byteArray)
                        {
                            *array = (byte)(v + 127);
                        }
                        return byteArray;
                    };
                case 2:
                    return v =>
                    {
                        fixed (byte* byteArray = shortArray)
                        {
                            short* shortArray = (short*)byteArray;
                            *shortArray = (short)v;
                        }
                        return shortArray;
                    };
                case 3:
                    return v =>
                    {
                        fixed (byte* byteArray = triArray)
                        {
                            int val = ((int)v) & 0x00_ff_ff_ff;
                            byte low = (byte)(val & 0x00_00_00_ff);
                            byte mid = (byte)((val & 0x00_00_ff_00) >> 8);
                            byte high = (byte)((val & 0x00_ff_00_00) >> 16);
                            byteArray[0] = low;
                            byteArray[1] = mid;
                            byteArray[2] = high;
                        }
                        return triArray;
                    };
                case 4:
                    return v =>
                    {
                        fixed (byte* byteArray = intArray)
                        {
                            int* intArray = (int*)byteArray;
                            *intArray = (int)v;
                        }
                        return intArray;
                    };
                default:
                    throw new InvalidOperationException(nameof(byteDepth));
            }
        }

        public static Func<double, double> SelectWaveform(DataGenOptions dataGenOptions)
        {
            return dataGenOptions.WaveformShape switch
            {
                WaveformShape.Sine => (double t) => Math.Sin(dataGenOptions.AngularFrequency * t),
                WaveformShape.Unknown => throw new NotImplementedException(),
                WaveformShape.Square => throw new NotImplementedException(),
                WaveformShape.Triangle => throw new NotImplementedException(),
                _ => throw new InvalidOperationException(nameof(dataGenOptions.WaveformShape)),
            };
        }

        public static void WriteWavHeader(DataGenOptions dataGenOptions, BinaryWriter binaryStream)
        {
            // https://docs.fileformat.com/audio/wav/
            binaryStream.Write(Encoding.ASCII.GetBytes("RIFF")); // 1-4
            binaryStream.Write((int)(44 + dataGenOptions.DataSectionByteCount - 8)); // 5-8
            binaryStream.Write(Encoding.ASCII.GetBytes("WAVE")); // 9-12
            binaryStream.Write(Encoding.ASCII.GetBytes("fmt ")); // 13-16
            binaryStream.Write(16); // 17-20
            binaryStream.Write((ushort)1); // 21-22
            binaryStream.Write(dataGenOptions.ChannelCount); // 23-24
            binaryStream.Write(dataGenOptions.SamplingRate); // 25-28
            binaryStream.Write(dataGenOptions.ChannelCount * dataGenOptions.SamplingRate * dataGenOptions.BitDepth / 8); // 29-32 bytes per second
            binaryStream.Write((ushort)(dataGenOptions.BitDepth * dataGenOptions.ChannelCount / 8)); // 33-34
            binaryStream.Write(dataGenOptions.BitDepth); // 35-36
            binaryStream.Write(Encoding.ASCII.GetBytes("data")); // 37-40
            binaryStream.Write(dataGenOptions.DataSectionByteCount); // 41-44
        }
    }

    public class DataGenOptions
    {
        public long SampleCount => SamplingRate * SecondLength;
        public int SamplingRate { get; set; }
        public int SecondLength { get; set; }
        public WaveformShape WaveformShape { get; set; }
        public string OutputFilePath { get; set; }
        public double Frequency { get; set; }
        public ushort ChannelCount { get; set; } = 1;
        public ushort BitDepth { get; set; } = 32;
        public ushort ByteDepth => (ushort)(BitDepth / 8);
        public int SampleSize => BitDepth / 8;
        public double AngularFrequency => 2 * Math.PI * Frequency;
        public double SampleLength => 1.0 / SamplingRate;
        public long DataSectionByteCount => SampleSize * SampleCount * ChannelCount;
    }

    public static class DataGenExtensions
    {
        public static DataGenOptions MapToOptions(this Program.Options options)
        {
            return new DataGenOptions
            {
                OutputFilePath = options.OutputFilePath,
                SamplingRate = options.SamplingRate,
                SecondLength = options.SecondLength,
                WaveformShape = options.WaveformShape,
                Frequency = options.Frequency,
                BitDepth = (ushort)options.BitDepth,
            };
        }
    }

    public enum WaveformShape
    {
        Unknown = 0,
        Sine,
        Square,
        Triangle
    }
}
