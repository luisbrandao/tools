Summary: Bash script that enables you to aggregate (tail/follow) logs from multiple pods into one stream.
Name: kubetail
Version: 1.6.7
Release: 3%{?dist}
License: GPLv2
Group: Applications/Tools
Source0: %{name}-%{version}.tar.bz2
BuildArch: noarch
URL: https://github.com/johanhaleby/kubetail

Requires: kubernetes-client
Requires: bash-completion

# No debug info for bare scripts, right?
%define debug_package %{nil}

# http://fedoraproject.org/wiki/Changes/UnversionedDocdirs
%{!?_pkgdocdir: %global _pkgdocdir %{_docdir}/%{name}-%{version}}
%global _docdir_fmt %{name}

%description
Bash script that enables you to aggregate (tail/follow) logs from multiple pods into one stream. This is the same as running "kubectl logs -f " but for multiple pods.

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
%{_sbindir}/kubetail
/etc/bash_completion.d/kubetail.bash

%changelog
* Mon Mar 25 2019 Luis Alexandre Deschamps Brandão <techmago@ymail.com> - 1.6.7
- Create rpm version of the script.
