#!/bin/bash

# Run only one instance of script at a time
LOCKFILE=/tmp/ombi-deb-build.txt
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "already running"
    exit
fi
# make sure the lockfile is removed when we exit and then claim it
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}

branches=(master develop);
architectures=(amd64 armhf arm64);
maintainer="Louis Laureys <louis@laureys.me>";

# Change to script directory
scriptPath="$( cd "$(dirname "$0")" ; pwd -P )";
cd $scriptPath;

for branch in "${branches[@]}"; do :
  # If master branch: use github releases, else: appveyor
  if [[ $branch == "master" ]]; then
    githubJson=$(curl -s -G -X GET "https://api.github.com/repos/Tidusjar/Ombi/releases")
    # Latest github release tag. e.g v3.0.3030
    githubTag=$(echo $githubJson | jq -r '.[0].tag_name')
    # Remove leading v
    latestVersion=${githubTag:1}
  else
    # Get latest 10 builds. Filter out failed, PR and tagged builds. Then return most recent version
    latestVersion=$(curl -s -G -X GET "https://ci.appveyor.com/api/projects/tidusjar/requestplex/history?recordsNumber=10&branch=${branch}" | jq -r '[.builds[] | select(.status == "success" and .pullRequestId == null and .isTag == false)] | .[0].version');
    if [[ ! -z "$1" ]]; then
      latestVersion="$1";
    fi
  fi
  for arch in "${architectures[@]}"; do :
    # Make directories if they don't exist already
    if [[ ! -d "${branch}/${arch}/builds" ]]; then
      mkdir "${branch}/${arch}/builds";
    fi;
    if [[ ! -d "${branch}/${arch}/template/ombi" ]]; then
      mkdir "${branch}/${arch}/template/ombi";
    fi;

    # If we don't already have this deb
    if [[ ! -f "${branch}/${arch}/builds/ombi_${latestVersion}_${arch}.deb" ]]; then
      versionDir="${branch}/${arch}/builds/ombi-${latestVersion}";
      if [[ ! -d $versionDir ]]; then
        echo "Getting new $branch build v${latestVersion}_${arch}";

        # Copy the deb template to new version dir
        cp -r "${branch}/${arch}/template" $versionDir;

        # Download and extract linux.tar.gz to build folder
        case $arch in
          amd64 )
            filename="linux.tar.gz" ;;
          armhf )
            filename="linux-arm.tar.gz" ;;
          arm64 )
            filename="linux-arm64.tar.gz" ;;
        esac;
        # If master branch: use github releases, else: appveyor
        if [[ $branch == "master" ]]; then
          downloadUrl=$(echo $githubJson | jq -r ".[0].assets[] | select( .name == \"${filename}\" ) | .browser_download_url")
        else
          jobId=$(curl -s -G -X GET "https://ci.appveyor.com/api/projects/tidusjar/requestplex/build/${latestVersion}" | jq -r '.build.jobs[].jobId');
          downloadUrl="https://ci.appveyor.com/api/buildjobs/${jobId}/artifacts/${filename}"
        fi
        archive="${versionDir}/ombi/${filename}";
        curl -L $downloadUrl --output $archive;
        tar -ixzvf $archive -C "${versionDir}/ombi/";
        rm $archive;

        # Replace keywords in template changelog with actual values
        sed -i "${versionDir}/debian/changelog" -e "s/@{VERSION}/${latestVersion}/g" -e "s/@{MAINTAINER}/${maintainer}/g" -e "s/@{DATE}/$(date -R)/g";

        # Build the thing!
        cd $versionDir;
        dpkg-buildpackage -b -us -uc -a $arch;
        cd $scriptPath;

        # If .deb was generated delete the build dir
        if [[ -f "${branch}/${arch}/builds/ombi_${latestVersion}_$arch.deb" ]]; then
          rm -rf $versionDir;
          newRelease=true;
        fi;

      else
        echo "Build directory for $branch v${latestVersion}_${arch} already exists!";
        echo "We're currently building this release or the previous build failed.";
        echo "If you're sure we're not currently building you can delete ${versionDir}/ and try again.";
      fi;
    else
      echo "We already have $branch v${latestVersion}_${arch}. Not building.";
    fi;
  done;
  # Execute custom script if a new deb was built and custom.sh exists. Use this to deploy to repo.
  if [[ $newRelease = true ]] && [[ -f "custom.sh" ]] ; then
    ./custom.sh ${branch} ${latestVersion};

    # Set $newRelease false for next branch
    newRelease=false
  fi
done;

rm -f ${LOCKFILE}
