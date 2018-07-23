Summary: List AWS instances
Name: list
Version: 1.0.0
Release: 1%{?dist}
License: GPLv2
Group: System Environment/Daemons
Source0: %{name}-%{version}.tar.bz2
BuildArch: noarch

Requires: python3-click
Requires: python3-terminaltables
Requires: python3-boto3

# No debug info for bare scripts, right?
%define debug_package %{nil}

# http://fedoraproject.org/wiki/Changes/UnversionedDocdirs
%{!?_pkgdocdir: %global _pkgdocdir %{_docdir}/%{name}-%{version}}
%global _docdir_fmt %{name}

%description
This list all your AWS EC2 instances, and format the output in a nice table

%prep
%setup -q


%build


%install
mkdir -p $RPM_BUILD_ROOT%{_sbindir}
%makeinstall DESTDIR=$RPM_BUILD_ROOT

%post


%preun

%postun

%files
%doc README.md
%{_sbindir}/list

%changelog
* Mon Jul 23 2018 Luis Alexandre Deschamps Brandão <techmago@ymail.com> - 1.0.0
- Create rpm version of the script.
