__declspec(dllimport) int winbridge_fixture_answer(void);

int winbridge_main(void)
{
    return winbridge_fixture_answer() == 42 ? 0 : 93;
}
