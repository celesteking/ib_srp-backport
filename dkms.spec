%define module  ib_srp
%define mkconf  dkms.mkconf

%define release_date "December 8, 2016"

Name:           %{module}-dkms

Version:        %{?MODVER}%{!?MODVER:2.0.41}
Release:        %{?REL}%{?!REL:2}%{?dist}
Summary:        dkms: %{module}

Group:          System Environment/Kernel
License:        GPLv2
URL:            http://www.fusionio.com/
Source0:        %{module}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{rel}-root-%(%{__id_u} -n)
BuildArch:      noarch

Requires:       dkms >= 2.2.0.3-20
Requires:       gcc, make, perl
Requires:       kernel-devel
Provides:       %{module}-kmod = %{version}

%define dkms_src %{_usrsrc}/%{module}-%{version}

%description
Backport of the Linux IB/SRP 4.2 kernel module to earlier kernel versions.
%{dist}

%prep
%setup -c  -q -n %{module}-%{version}

%build
%{__cat} > dkms.conf << 'EOF'
PACKAGE_NAME=%{name}
PACKAGE_VERSION=%{version}
RELEASE_DATE=%{release_date}
MAKE[0]="make"
REMAKE_INITRD="no"
BUILT_MODULE_NAME[0]=scsi_transport_srp
BUILT_MODULE_LOCATION[0]=drivers/scsi
BUILT_MODULE_NAME[1]=ib_srp
BUILT_MODULE_LOCATION[1]=drivers/infiniband/ulp/srp
DEST_MODULE_LOCATION[0]=/extra
DEST_MODULE_LOCATION[1]=/extra
AUTOINSTALL="YES"
EOF

%install
%{__rm} -rf %{buildroot}
%{__install} -d %{buildroot}%{dkms_src}

%{__cp} -a dkms.conf drivers include Makefile conftest %{buildroot}%{dkms_src}/

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root)
/usr/src/%{module}-%{version}

%post
for POSTINST in /usr/lib/dkms/common.postinst; do
    if [ -f $POSTINST ]; then
        $POSTINST %{module} %{version}
        exit $?
    fi
    echo "WARNING: $POSTINST does not exist."
done
echo -e "ERROR: DKMS version is too old"
exit 1

%preun
dkms remove -m %{module} -v %{version} --all --rpm_safe_upgrade || :

%changelog
* %(date "+%a %b %d %Y") %packager %{version}-%{release}
- Automatic build by DKMS
