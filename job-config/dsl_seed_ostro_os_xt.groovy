//
// DSL script to generate XT toplevel job
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

import jenkins.model.*

def scm_poll = 'H/15 * * * *';

def credentials_github_https = "github-auth-https";

def vars = [:]
Jenkins.instance.getGlobalNodeProperties().each { it ->
  if (it instanceof hudson.slaves.EnvironmentVariablesNodeProperty) {
    it.getEnvVars().each { key, val ->
      if (key.startsWith('OSTRO')) {
        vars[key] = val
      }
    }
  }
}

def github_org = vars.getOrDefault('OSTRO_GITHUB_ORG', 'ostroproject')
def github_public = vars.getOrDefault('OSTRO_PUBLIC_GITHUB_ORG','')
def github_private = vars.getOrDefault('OSTRO_PRIVATE_GITHUB_ORG','')
def whitelist_orgs = vars.getOrDefault('OSTRO_WHITELIST_ORGS', '01org solettaproject').tokenize(', ')

if (github_public && github_public != github_org) {
    whitelist_orgs.add(github_public)
}
if (github_private && github_private != github_org) {
    whitelist_orgs.add(github_private)
}
whitelist_orgs.add(github_org)

def global_admins = ["kad", "okartau", "mythi", "pohly"]


// Generate Ostro XT job
pipelineJob("ostro-os-xt_master") {
  description("Automatically generated. Ostro OS XT product master job. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(499)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  parameters {
    stringParam('BASE_DISTRO_BRANCH', 'master', 'Git revision to use for base distro')
  }
  environmentVariables {
    env('COORD_BASE_URL', "http://ostroci.ostc/download/ostro-os-xt")
    env('RSYNC_PUBLISH_DIR', "rsync://ostrostore.ost.int/ostro-os-xt")
    env('PUBLISH_DIR', "/srv/ostro/ostro-os-xt")
    keepSystemVariables(true)
    keepBuildVariables(true)
  }
  concurrentBuild()
  triggers {
    githubPush()
    scm("${scm_poll}")
  }
  definition {
    cpsScm {
      scm {
        git {
          remote {
            github(github_org+"/ostro-os-xt", protocol="https")
            credentials('github-auth-https')
          }
          branches('*/master')
          extensions {
            submoduleOptions {
              recursive(true)
              reference('/srv/ostro/ostro-os-xt/bb-cache/.git-mirror')
            }
          }
        }
      }
      scriptPath('Jenkinsfile')
    }
  }
}

// Generate Ostro XT PR job
pipelineJob("ostro-os-xt_pull-requests") {
  description("Automatically generated. Ostro OS XT PR job. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(499)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  properties {
    githubProjectUrl('https://github.com/ostroproject/ostro-os-xt/')
  }
  parameters {
    stringParam('BASE_DISTRO_BRANCH', 'master', 'Git revision to use for base distro')
    stringParam('GITHUB_PROJECT', 'https://github.com/ostroproject/ostro-os-xt', 'URL to github repo')
    stringParam('GITHUB_AUTH', 'github-auth-https', 'credentials to use')
  }
  environmentVariables {
    //env('CI_PUBLISH_NAME', "ostro-os-xt")
    env('COORD_BASE_URL', "http://ostroci.ostc/download/ostro-os-xt")
    env('RSYNC_PUBLISH_DIR', "rsync://ostrostore.ost.int/ostro-os-xt")
    env('PUBLISH_DIR', "/srv/ostro/ostro-os-xt")
    keepSystemVariables(true)
    keepBuildVariables(true)
  }
  concurrentBuild()
  triggers {
    gitHubPRTrigger {
      spec('H/3 * * * *')
      triggerMode("CRON")
      preStatus(true)
      events {
        gitHubPRNonMergeableEvent { skip(true) }
        gitHubPRDescriptionEvent { skipMsg('.*\\[skip[\\W-]+ci\\].*') }
        gitHubPROpenEvent()
        gitHubPRCommitEvent()
        gitHubPRCommentEvent { comment('.*test\\W+(this|it)\\W+please.*') }
      }
      /*
      userRestriction {
        orgs(whitelist_orgs.unique().join(" "))
        users("")
        whitelistUserMsg("Can some of admins review this patch ?")
      }
      */
    }
  }
  definition {
    cps {
      script(readFileFromWorkspace('ostroproject-ci/job-config/xt-pr-node.groovy'))
      sandbox()
    }
  }
}
