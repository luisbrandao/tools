# This file should be sourced

bucketpull () {
  if [ ! -z "$1" ] ; then
    export bucket="rentcars-projects/settings/${1}"
  fi
  if [ -z "${bucket}" ] ; then
    echo 'Bucket undefined!'
    echo 'bucket="rentcars-projects/settings/site"'
  else
    echo "Pulling from ${bucket}"
    cd ~/s3tmp && rm -rf ~/s3tmp/*
    aws s3 sync s3://${bucket}/ ./
  fi
}

bucketpush () {
  if [ -z "${bucket}" ] ; then
    echo 'Bucket undefined!'
    echo 'bucket="rentcars-projects/settings/site"'
  else
    echo "Push to ${bucket}"
    aws s3 sync ./ s3://${bucket}/
  fi
}
