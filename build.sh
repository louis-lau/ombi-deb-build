#!/bin/bash

branches=(master develop)
architectures=(amd64 armhf)
maintainer="Louis Laureys <louis@laureys.me>"

# Change to script directory
scriptPath="$( cd "$(dirname "$0")" ; pwd -P )"
cd $scriptPath

for branch in "${branches[@]}"; do :
# Get latest 10 builds. Filter out failed, cancelled, PR. Then return most recent version
latestVersion=$(curl -s -G -X GET "https://ci.appveyor.com/api/projects/tidusjar/requestplex/history?recordsNumber=10&branch=${branch}" | jq -r '[.builds[] | select(.status == "success" and .pullRequestId == null)] | .[0].version');
jobId=$(curl -s -G -X GET "https://ci.appveyor.com/api/projects/tidusjar/requestplex/build/${latestVersion}" | jq -r '.build.jobs[].jobId');
  for arch in "${architectures[@]}"; do :
    if [[ ! -d "${branch}/${arch}/builds" ]]; then
      mkdir "${branch}/${arch}/builds"
    fi
    if [[ ! -d "${branch}/${arch}/template/ombi" ]]; then
      mkdir "${branch}/${arch}/template/ombi"
    fi
    if [[ ! -f "${branch}/${arch}/builds/ombi_${latestVersion}_${arch}.deb" ]]; then
      versionDir="${branch}/${arch}/builds/ombi-${latestVersion}";
      if [[ ! -d $versionDir ]]; then
        echo "Getting new $branch build v${latestVersion}_${arch}";

        # Copy the deb template to new version dir
        cp -r "${branch}/${arch}/template" $versionDir;

        case $arch in
          amd64 )
          filename="linux.tar.gz";;
          armhf )
          filename="linux-arm.tar.gz";;
        esac
        archive="${versionDir}/ombi/${filename}";
        curl -L "https://ci.appveyor.com/api/buildjobs/${jobId}/artifacts/${filename}" --output $archive;
        tar -xf $archive -C "${versionDir}/ombi/";
        rm $archive;

        # Replace keywords in template changelog with actual values
        sed -i "${versionDir}/debian/changelog" -e "s/@{VERSION}/${latestVersion}/g" -e "s/@{MAINTAINER}/${maintainer}/g" -e "s/@{DATE}/$(date -R)/g";

        # Build the thing!
        cd $versionDir;
        dpkg-buildpackage -b -us -uc -a $arch
        cd $scriptPath;

        # if .deb was generated delete the dir
        if [[ -f "${branch}/${arch}/builds/ombi_${latestVersion}_$arch.deb" ]]; then
          rm -rf $versionDir;
        fi

      else
        echo "Build directory for $branch v${latestVersion}_${arch} already exists!";
        echo "We're currently building this release or the previous build failed."
        echo "If you're sure we're not currently building you can delete ${versionDir}/ and try again."
      fi;
    else
      echo "We already have $branch v${latestVersion}_${arch}. Not building."
    fi
  done
done