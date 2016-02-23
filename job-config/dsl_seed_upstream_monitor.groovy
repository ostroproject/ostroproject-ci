//
// DSL script to generate the upstream monitor job
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

// Imports:
import jenkins.model.*
import org.ini4j.*;

ini = new Wini(new File("${WORKSPACE}/ostro-os/conf/combo-layer.conf"));

def credentials_github_ssh = "github-auth-ssh";
def credentials_github_https = "github-auth-https";
def credentials_github_token = "github-auth-token"
def job_name = 'upstream-monitor-master'
def refspec_str = '+refs/heads/*:refs/remotes/origin/* +refs/*:refs/remotes/origin_mirror/*';

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

def ostro_ci_server = vars.getOrDefault('OSTRO_CI_SERVER','production')
def github_org = vars.getOrDefault('OSTRO_GITHUB_ORG', 'ostroproject')
def github_public = vars.getOrDefault('OSTRO_PUBLIC_GITHUB_ORG','')
def github_private = vars.getOrDefault('OSTRO_PRIVATE_GITHUB_ORG','')

def repo_substitution = [
      'meta-iotqa': 'ostroproject-meta-iotqa',
      'meta-appfw': 'ostroproject-meta-appfw',
      'meta-iot-web': 'ostroproject-meta-iot-web',
      'iot-app-fw': 'ostroproject-iot-app-fw' ]

println ini.keySet()

println "Generating job ${job_name}";
freeStyleJob("${job_name}") {
  label("master")
  description("Automatically generated job. Don't touch manually.")
  logRotator {
    daysToKeep(-1)
    numToKeep(499)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  disabled(DISABLE_JOBS.toBoolean())
  wrappers {
    sshAgent('github-auth-ssh')
    credentialsBinding {
      string('GITHUB_TOKEN', credentials_github_token)
    }
    timestamps()
  }
  environmentVariables {
    propertiesFile('${HOME}/ci/conf/configuration')
    keepSystemVariables(true)
    keepBuildVariables(true)
  }
  multiscm {
    for (section in ini.keySet()) {
      src_uri = ini.get(section, "src_uri");
      layer_branch = ini.get(section, "branch");
      if (src_uri) {
        match = src_uri =~ $/(?:(|ssh|https?|git)://)?(git@)?github.com[:/]([\w\.-]+)/([\w\.-]+?)(?:\.git)?/?$$/$
        creds = ""
        if (match?.count) {
          def (fullm, m_proto, m_user, m_owner, m_repo) = match[0]
          if (!m_proto && m_user == "git@") {
              m_proto = "ssh"
          }
          if( m_proto == "ssh") {
              creds = credentials_github_ssh;
          } else if (m_proto =="http" || m_proto == "https") {
              creds = credentials_github_https;
              // enforce https
              m_proto = "https"
          } else {
              creds = ""
          }
          if (github_public == m_owner && github_public && github_org != github_public) {
            m_owner = github_private
            if (repo_substitution.containsKey(m_repo)) {
              m_repo = repo_substitution[m_repo]
            }
          }
          git {
            remote {
              github(m_owner+"/"+m_repo, protocol=m_proto)
              if (creds) {
                println "debug: ${src_uri} -> ${creds}";
                credentials("${creds}")
              }
              // name(section)
            }
            branches(layer_branch)
            // remotePoll(false)
            extensions {
              relativeTargetDirectory(section)
              cloneOptions {
                timeout(30)
              }
            }
          }
        } else {
          git {
            remote {
              url(src_uri)
              // name(section)
            }
            branches(layer_branch)
            // remotePoll(false)
            extensions {
              relativeTargetDirectory(section)
              cloneOptions {
                timeout(30)
              }
            }
          }
        }
      }
    }
    git {
      remote {
        github(MAIN_REPO, protocol='ssh')
        credentials('github-auth-ssh')
        // name(MAIN_REPO_NAME)
      }
      branches(MAIN_REPO_BRANCH)
      extensions {
        relativeTargetDirectory(MAIN_REPO_NAME)
        cloneOptions {
          timeout(30)
        }
      }
    }
  }
  triggers {
    scm('H/15 * * * *')
    githubPush()
  }
  steps {
    shell("""
\${HOME}/ci/bin/upstream-monitor.sh
""")
  }
  publishers {
    irc {
      channel('#ostroproject', '', true)
      notificationMessage('SummaryOnly')
      strategy('FAILURE_AND_FIXED')
    }
  }
}
