//
// DSL script to generate mirroring jobs
// Copyright (c) 2016, Intel Corporation.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms and conditions of the GNU General Public License,
// version 2, as published by the Free Software Foundation.
//
// This program is distributed in the hope it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.
//
import org.ini4j.*;

ini = new Wini(new File("${WORKSPACE}/ostro-os/conf/combo-layer.conf"));

def credentials_github_ssh = "github-auth-ssh";
def credentials_github_https = "github-auth-https";
def job_name_prefix = 'mirror-layer'
def refspec_str = '+refs/heads/*:refs/remotes/origin/* +refs/*:refs/remotes/origin_mirror/*';

println ini.keySet()
// define combined repo as 1st elems of arrays, lets us to use same loop
def sections = [ 'ostro-os' ]
def src_uris = [ 'git@github.com:ostroproject/ostro-os' ]

// add values from combo-layer.conf to sections and src_uris arrays
for (section in ini.keySet()) {
  src_uri = ini.get(section, "src_uri");
  sections.add(section)
  src_uris.add(src_uri)
}

// generate jobs based on arrays values, main repo followed by layer repos
for (int i = 0; i < sections.size() ; i++) {
  section = sections[i]
  src_uri = src_uris[i]
  if (src_uri) {
    println "X: ${section} URL: ${src_uri}";
    if (src_uri ==~ /git@github.com[:\/].+/) {
      println "Using GitHub ssh credentials";
      creds = credentials_github_ssh;
    } else if ( src_uri ==~ /https?:\/\/.*github.com\/.+/ ) {
      println "Using GitHub https credentials";
      creds = credentials_github_https;
    } else {
      println "No credentials";
      creds = "";
    }
    println "Generating job ${job_name_prefix}-${section}";
    freeStyleJob("${job_name_prefix}-${section}") {
      label("master")
      description("Automatically generated job. Don't touch manually.")
      logRotator {
        daysToKeep(-1)
        numToKeep(99)
        artifactDaysToKeep(-1)
        artifactNumToKeep(-1)
      }
      disabled(DISABLE_JOBS.toBoolean())
      wrappers {
        timestamps()
      }
      scm {
        git {
          remote {
            url(src_uri)
            if (creds) {
              println "debug: ${src_uri} -> ${creds}";
              credentials("${creds}")
            }
            name("origin")
            refspec("${refspec_str}")
          }
          extensions {
            cloneOptions {
              timeout(30)
              reference("/srv/git_mirror/${section}.git")
            }
          }
          //branches("refs/remotes/origin/*")
        }
      }
      steps {
        shell("""
if [ ! -d /srv/git_mirror/${section}.git ]; then
  git init --bare /srv/git_mirror/${section}.git 
fi
git push /srv/git_mirror/${section}.git --force --prune refs/remotes/origin_mirror/*:refs/*
""")
      }
      triggers {
        scm('H/15 * * * *')
      }
    }
  }
}
