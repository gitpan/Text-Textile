use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Text::Textile',
    'VERSION_FROM'	=> 'Textile.pm', # finds $VERSION
    'PREREQ_PM'		=> {
                              'HTML::Entities'=>undef,
                              'Test::Simple'=>undef,
                           },
);
