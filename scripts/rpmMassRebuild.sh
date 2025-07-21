alias rbuild="rpmbuild -ba -D 'debug_package %{nil}'"
alias b="rpmbuild --rebuild --define 'debug_package %{nil}'"

for file in *; do
    echo "Processing $file"
    dnf builddep -y ${file}
    b ${file}
    if [ $? -eq 0 ]; then
        rm -f ${file}
    fi
done
