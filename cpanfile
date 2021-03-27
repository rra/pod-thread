# -*- perl -*-

on 'test' => sub {
    requires 'Devel::Cover';
    requires 'Perl6::Slurp';
    requires 'Perl::Critic::Freenode';
    requires 'Test::MinimumVersion';
    requires 'Test::Perl::Critic';
    requires 'Test::Pod';
    requires 'Test::Spelling';
    requires 'Test::Strict';
    requires 'Test::Synopsis';
};
