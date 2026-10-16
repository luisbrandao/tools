Summary: Custom (aggressive) NVIDIA GPU fan controller with systemd service
Name: tech-fancontrol
Version: 1.0.0
Release: 1%{?dist}
License: GPLv2
Group: Applications/Tools
Source0: %{name}-%{version}.tar.bz2
BuildArch: noarch

BuildRequires: systemd-rpm-macros

Requires: python3
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd
Recommends: python3-nvidia-ml-py

# No debug info for bare scripts, right?
%define debug_package %{nil}
%define _build_id_links none

# http://fedoraproject.org/wiki/Changes/UnversionedDocdirs
%{!?_pkgdocdir: %global _pkgdocdir %{_docdir}/%{name}-%{version}}
%global _docdir_fmt %{name}

%description
Python/NVML based GPU fan controller with a custom temperature-to-speed
curve (more aggressive than the stock one). Handles every fan zone per
GPU, has hysteresis, a failsafe on NVML errors and restores automatic
fan control on service stop. Installs a systemd service; settings live
in /etc/sysconfig/tech-fancontrol.

%prep
%setup -q


%build


%install
mkdir -p $RPM_BUILD_ROOT%{_sbindir}
mkdir -p $RPM_BUILD_ROOT%{_unitdir}
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig
%makeinstall DESTDIR=$RPM_BUILD_ROOT

%post
%systemd_post tech-fancontrol.service

%preun
%systemd_preun tech-fancontrol.service

%postun
%systemd_postun_with_restart tech-fancontrol.service

%files
%doc README.md
%config(noreplace) %{_sysconfdir}/sysconfig/tech-fancontrol
%{_sbindir}/tech-fancontrol
%{_unitdir}/tech-fancontrol.service

%changelog
* Fri Oct 16 2026 Luis Alexandre Deschamps Brandão <techmago@ymail.com> - 1.0.0
- First packaged version (was /root/bin/fan-control.py on gw.brandao).
