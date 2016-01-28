perl C:\Perl64\lib\ExtUtils\xsubpp -typemap C:\Perl64\lib\ExtUtils\typemap CL.xs > CL.c
perl -MExtUtils::Embed -e xsinit -- -o xsinit.c CL DynaLoader
perl packmod.pl AutoLoader DynaLoader=DLWin32.pm Carp Carp::Heavy warnings::register warnings strict integer vars fields base locale Exporter Exporter::Heavy Symbol Text::ParseWords Ex CL Conf CMD LE Parser MUD Keymap Main RStream DCommand Ticker Status UAPI > perlmodules.c
