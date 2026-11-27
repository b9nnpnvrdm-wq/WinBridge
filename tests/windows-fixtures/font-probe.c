typedef void *DeviceContext;

__declspec(dllimport) DeviceContext CreateCompatibleDC(DeviceContext compatible);
__declspec(dllimport) int GetTextMetricsA(DeviceContext context, void *metrics);
__declspec(dllimport) int DeleteDC(DeviceContext context);

int winbridge_main(void)
{
    /* TEXTMETRICA starts with a signed 32-bit height and fits in 128 bytes. */
    long metrics[32];
    DeviceContext context = CreateCompatibleDC(0);
    if (!context)
        return 91;
    int has_font = GetTextMetricsA(context, metrics) && metrics[0] > 0;
    DeleteDC(context);
    return has_font ? 0 : 92;
}
