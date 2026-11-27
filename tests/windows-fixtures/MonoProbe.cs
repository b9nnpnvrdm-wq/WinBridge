using System;

internal static class MonoProbe
{
    private static int Main()
    {
        Console.WriteLine("WINBRIDGE_MONO_OK");
        return Type.GetType("Mono.Runtime") != null ? 0 : 91;
    }
}
