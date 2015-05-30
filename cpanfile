requires 'perl', '5.008001';

requires 'LWP::Protocol::PSGI';
requires 'Plack::Request';
requires 'List::MoreUtils';
requires 'Test::More', '0.98';

## Feature::Fixture
requires 'LWP::UserAgent'; # Also in test
requires 'HTTP::Request';
requires 'Path::Class';
requires 'Plack::Response';
requires 'Class::Accessor::Lite';

on 'test' => sub {
    requires 'Test::Class';
    requires 'Test::Deep';
    requires 'Test::Tester';
    # requires 'LWP::UserAgent';
    requires 'HTTP::Response';
    requires 'Path::Class';
    requires 'File::Temp';
};

