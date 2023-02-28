import sys
from subprocess import STDOUT, check_call, check_output

# get packages
packages = check_output(['ls', '/root/pkg']).split()
packages = sorted(packages, reverse=True)
onedatafs_py3_package = [path for path in packages
                         if path.startswith('onedata{release}-python3-onedatafs'.format(release='2102'))][0]

fsonedatafs_py3_package = [path for path in packages
                         if path.startswith('onedata{release}-python3-fs-onedatafs'.format(release='2102'))][0]

# install Python prerequisites
check_call(['yum', '-y', 'install', 'python36-pip'])
check_call(['pip3', 'install', 'setuptools', 'six', 'fs'])

# install onedatafs packages for Python3
check_call(['yum', '-y', '--enablerepo=onedata', 'install',
            '/root/pkg/' + onedatafs_py3_package], stderr=STDOUT)

# install fsonedatafs packages for Python3
check_call(['yum', '-y', '--enablerepo=onedata', 'install',
            '/root/pkg/' + fsonedatafs_py3_package], stderr=STDOUT)

# Remove glusterfs libs comming from onedata2102 repo
# After publishing stable 21.02 the libs should be removed from repo 
# as well as the erasing check_call here
# TODO VFS-10570 Remove after publishing stable release 21.02
check_call(['yum', '-y', 'erase', 'onedata2102-glusterfs-libs', 'onedata2102-glusterfs', 'onedata2102-glusterfs-client-xlators', 'onedata2102-glusterfs-api'])

# validate onedatafs Python3 package installation
check_call(['scl', 'enable', 'onedata{release}'.format(release='2102'), 'PYTHONPATH="${ONEDATA_PYTHON3_PATH}" python3 -c "from fs.onedatafs import OnedataFS"'])

sys.exit(0)
