use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME	=> 'SQL::SyntaxModel::SkipID',
	VERSION => 0.29, # for the distribution itself, not of individual modules
	PREREQ_PM => {
		'Locale::KeyedText' => 0.04,
		'SQL::SyntaxModel' => 0.22,
	},
);