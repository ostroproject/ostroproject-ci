//
// DSL script to generate toplevel jobs that call build and test phases
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

// toplevel jobs are:
// 1. layer pull request jobs
// 2. layer head jobs
// 3. combined repo pull request job
// 4. master (combined repo) job
// additionally in this file, to re-use list of test_targets:
// 5. tester-re-test-existing-build

import jenkins.model.*
import org.ini4j.*;
ini = new Wini(new File("${WORKSPACE}/ostro-os/conf/combo-layer.conf"));

def ci_branch = 'master';
def build_targets = 'build_beaglebone,build_edison,build_intel-corei7-64,build_intel-quark';
def test_targets = 'test_beagleboneblack,test_edison,test_galileov2,test_gigabyte,test_minnowboardmax';

def refspec_str_metalayer = '+refs/heads/*:refs/remotes/origin/*';
def scm_poll = 'H/15 * * * *';
def scm_poll_short = 'H/5 * * * *';

def credentials_github_ssh = "github-auth-ssh";
def credentials_github_https = "github-auth-https";
def refspec_str = '+refs/pull/*:refs/remotes/origin/pr/*';

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
def whitelist_orgs = vars.getOrDefault('OSTRO_WHITELIST_ORGS', '01org solettaproject').tokenize(', ')

if (github_public && github_public != github_org) {
    whitelist_orgs.add(github_public)
}
if (github_private && github_private != github_org) {
    whitelist_orgs.add(github_private)
}
whitelist_orgs.add(github_org)

def global_admins = ["kad", "okartau", "mythi", "pohly"]
def repo_admins = [
  'meta-appfw': ['juimonen', 'klihub'],
  'meta-intel-iot-middleware': ['tripzero'],
  'meta-intel-iot-security': ['pohly', 'ipuustin', 'johnwhiteman'],
  'meta-iot-web': ['nagineni', 'poussa'],
  'meta-iotqa': ['testkit', 'jwang11', 'xfzheng'],
  // global 'meta-ostro': [],
  'meta-ostro-bsp': ['jlaako', 'ipuustin'],
  // global 'meta-ostro-fixes': [],
  'meta-security-isafw': ['ereshetova'],
  'meta-soletta': ['brunobottazzini', 'bdilly', 'barbieri']
]

def repo_substitution = [
      'meta-iotqa': 'ostroproject-meta-iotqa',
      'meta-appfw': 'ostroproject-meta-appfw',
      'meta-iot-web': 'ostroproject-meta-iot-web',
      'iot-app-fw': 'ostroproject-iot-app-fw' ]

println ini.keySet()

// 1. and 2. generate pull request jobs and layer head jobs in same loop
for (section in ini.keySet()) {
  src_uri = ini.get(section, "src_uri");
  layer_branch = ini.get(section, "branch");

  if (src_uri) {
    match = src_uri =~ $/(?:(|ssh|https?|git)://)?(git@)?github.com[:/]([\w\.-]+)/([\w\.-]+?)(?:\.git)?/?$$/$
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

      println "INFO: ${section} URL: ${src_uri} branch_in_combolayer_conf: ${layer_branch}";
      if ( !(m_owner in whitelist_orgs) ) {
        println "Skipping project from non-whitelisted organisation"
        continue
      }

      // generate pull request job
      freeStyleJob("${section}_pull-requests") {
        label("master")
        description("Automatically generated. Manual changes will be overriden by next seed job run.")
        logRotator {
          daysToKeep(-1)
          numToKeep(99)
          artifactDaysToKeep(-1)
          artifactNumToKeep(-1)
        }

        //parameters {
          //stringParam('sha1', null, null)
        //}
        concurrentBuild()
        disabled(DISABLE_JOBS.toBoolean())
        wrappers {
          sshAgent('github-auth-ssh')
          timestamps()
        }
        environmentVariables {
          env('CI_PUBLISH_NAME', "${section}")
          env('PUBLISH_DIR_SUFFIX', "_pull-requests")
          propertiesFile('${HOME}/ci/conf/configuration')
          keepSystemVariables(true)
          keepBuildVariables(true)
        }
        scm {
          git {
            remote {
              github(m_owner+"/"+m_repo, protocol=m_proto)
              if (creds) {
                //println "debug: ${src_uri} -> ${creds}";
                credentials("${creds}")
              }
              name("origin")
              refspec("${refspec_str}")
            }
            branch('${sha1}')
          }
        }
        triggers {
          githubPullRequest {
            cron("${scm_poll}")
            // permitAll()
            def job_admins = []
            if (global_admins) {
              job_admins.addAll(global_admins)
            }
            if (m_repo in repo_admins) {
              job_admins.addAll(repo_admins[m_repo])
            }
            if (job_admins) {
              admins(job_admins.unique())
            }
            if (whitelist_orgs) {
              orgWhitelist(whitelist_orgs.unique())
            }
            //autoCloseFailedPullRequests()
            useGitHubHooks()
            extensions {
              commitStatus {
                context('OstroProjectCI')
                startedStatus('build started')
                //triggeredStatus('--none--')
                completedStatus('SUCCESS', 'SUCCESS')
                completedStatus('ERROR', 'ERROR')
                completedStatus('FAILURE', 'FAILURE')
              }
            }
          }
        }
        steps {
          shell('${HOME}/ci/bin/build-metalayer.sh')
          downstreamParameterized {
            trigger('build-prepare') {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
          downstreamParameterized {
            trigger('build-recipe-selftests') {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
          downstreamParameterized {
            trigger("${build_targets}") {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
          shell('${HOME}/ci/bin/prepare-testinfo.sh')
          downstreamParameterized {
            trigger("${test_targets}") {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
              parameterFactories {
                forMatchingFiles('*.testruns.csv', 'testinfo.csv')
              }
            }
          }
          shell('${HOME}/ci/bin/fetch-testresults-into-workspace.sh')
          downstreamParameterized {
            trigger('build-finalize') {
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
        }
        publishers {
          downstreamParameterized {
            trigger('build-post') {
              parameters {
                propertiesFile('env.properties')
              }
              condition('ALWAYS')
            }
          }
          archiveXUnit {
            jUnit {
              pattern('${TESTRESULTS_DIR}/${BUILD_TIMESTAMP}-build-${BUILD_NUMBER}-${CI_PUBLISH_NAME}-testing_*/TEST-*.xml')
              failIfNotNew(false)
            }
            failedThresholds {
              unstable(9999)
              unstableNew(9999)
              failure(0)
              failureNew(0)
            }
            skippedThresholds {
              unstable(9999)
              unstableNew(9999)
              failure(9999)
              failureNew(9999)
            }
            thresholdMode(ThresholdMode.NUMBER)
            timeMargin(3000)
          }
          groovyPostBuild('def run = Thread.currentThread().executable\n\
def   en = run.getEnvironment()\n\
if (en["GIT_BRANCH"] != "")\n\
  manager.addShortText(en["GIT_BRANCH"])', Behavior.DoNothing)
          if (src_uri ==~ /.*github.com[:\/]ostroproject.+/) {
            githubCommitNotifier()
          }
        }
      }
      // generate layer head job
      freeStyleJob("${section}_${ci_branch}") {
        label("master")
        description("Automatically generated. Manual changes will be overriden by next seed job run.")
        logRotator {
          daysToKeep(-1)
          numToKeep(99)
          artifactDaysToKeep(-1)
          artifactNumToKeep(-1)
        }

        disabled(DISABLE_JOBS.toBoolean())
        wrappers {
          sshAgent('github-auth-ssh')
          timestamps()
        }
        environmentVariables {
          env('CI_PUBLISH_NAME', "${section}_${ci_branch}")
          propertiesFile('${HOME}/ci/conf/configuration')
          keepSystemVariables(true)
          keepBuildVariables(true)
        }
        scm {
          git {
            remote {
              url(src_uri)
              if (creds) {
                //println "debug: ${src_uri} -> ${creds}";
                credentials("${creds}")
              }
              name("origin")
              refspec("${refspec_str_metalayer}")
            }
            extensions {
              cloneOptions {
                timeout(30)
                reference("/srv/git_mirror/${section}.git")
              }
            }
            branches("refs/heads/${layer_branch}")
          }
        }
        triggers {
          scm("${scm_poll}")
        }
        steps {
          shell('${HOME}/ci/bin/build-metalayer.sh')
          downstreamParameterized {
            trigger('build-prepare') {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
          downstreamParameterized {
            trigger('build-recipe-selftests') {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
          downstreamParameterized {
            trigger("${build_targets}") {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
          shell('${HOME}/ci/bin/prepare-testinfo.sh')
          downstreamParameterized {
            trigger("${test_targets}") {
              block {
                buildStepFailure('FAILURE')
                failure('FAILURE')
                unstable('UNSTABLE')
              }
              parameters {
                propertiesFile('env.properties')
              }
              parameterFactories {
                forMatchingFiles('*.testruns.csv', 'testinfo.csv')
              }
            }
          }
          //// PR rebuilds idea was active in early phases, passive now.
          //downstreamParameterized {
          //  trigger('pull-request-rebuilder') {
          //    parameters {
          //      predefinedProp('LAYER_REPOS', "${src_uri}")
          //    }
          //  }
          //}
          shell('${HOME}/ci/bin/fetch-testresults-into-workspace.sh')
          downstreamParameterized {
            trigger('build-finalize') {
              parameters {
                propertiesFile('env.properties')
              }
            }
          }
        }
        publishers {
          downstreamParameterized {
            trigger('build-post') {
              parameters {
                propertiesFile('env.properties')
              }
              condition('ALWAYS')
            }
          }
          archiveXUnit {
            jUnit {
              pattern('${TESTRESULTS_DIR}/${BUILD_TIMESTAMP}-build-${BUILD_NUMBER}-${CI_PUBLISH_NAME}-testing_*/TEST-*.xml')
              failIfNotNew(false)
            }
            failedThresholds {
              unstable(9999)
              unstableNew(9999)
              failure(0)
              failureNew(0)
            }
            skippedThresholds {
              unstable(9999)
              unstableNew(9999)
              failure(9999)
              failureNew(9999)
            }
            thresholdMode(ThresholdMode.NUMBER)
            timeMargin(3000)
          }

          groovyPostBuild('def run = Thread.currentThread().executable\n\
def en = run.getEnvironment()\n\
if (en["GIT_COMMIT"] != "")\n\
  manager.addShortText(en["GIT_COMMIT"])', Behavior.DoNothing)
        }
      }
    }
  }
}

// 3. combined repo pull request job
freeStyleJob('ostro-os_pull-requests') {
  label("master")
  description("Automatically generated. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(499)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  //parameters {
    //stringParam('sha1', null, null)
  //}
  concurrentBuild()
  disabled(DISABLE_JOBS.toBoolean())
  wrappers {
    sshAgent('github-auth-ssh')
    timestamps()
  }
  environmentVariables {
    env('CI_PUBLISH_NAME', "ostro-os")
    env('PUBLISH_DIR_SUFFIX', "_pull-requests")
    env('CI_REUSE_SSTATE', "defined")
    env('CI_ARCHIVER_MODE', "defined")
    propertiesFile('${HOME}/ci/conf/configuration')
    keepSystemVariables(true)
    keepBuildVariables(true)
  }
  scm {
    git {
      remote {
        github(github_org+"/ostro-os", protocol="ssh")
        credentials('github-auth-ssh')
        name("origin")
        refspec("${refspec_str}")
      }
      branch('${sha1}')
      extensions {
        cloneOptions {
          timeout(30)
          reference("/srv/git_mirror/ostro-os.git")
        }
      }
    }
  }
  triggers {
    githubPullRequest {
      cron("${scm_poll_short}")
      def job_admins = []
      if (global_admins) {
        job_admins.addAll(global_admins)
      }
      if (job_admins) {
        admins(job_admins.unique())
      }
      if (whitelist_orgs) {
        orgWhitelist(whitelist_orgs.unique())
      }
      useGitHubHooks()
      extensions {
        commitStatus {
          context('OstroProjectCI')
          startedStatus('build started')
          //triggeredStatus('--none--')
          completedStatus('SUCCESS', 'SUCCESS')
          completedStatus('ERROR', 'ERROR')
          completedStatus('FAILURE', 'FAILURE')
        }
      }
    }
  }
  steps {
    shell('${HOME}/ci/bin/build-prepare-master.sh .')
    downstreamParameterized {
      trigger('build-prepare') {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    downstreamParameterized {
      trigger('build-recipe-selftests') {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    downstreamParameterized {
      trigger("${build_targets}") {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    shell('${HOME}/ci/bin/prepare-testinfo.sh')
    downstreamParameterized {
      trigger("${test_targets}") {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
        parameterFactories {
          forMatchingFiles('*.testruns.csv', 'testinfo.csv')
        }
      }
    }
    shell('${HOME}/ci/bin/fetch-testresults-into-workspace.sh')
    downstreamParameterized {
      trigger('build-finalize') {
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
  }
  publishers {
    downstreamParameterized {
      trigger('build-post') {
        parameters {
          propertiesFile('env.properties')
        }
        condition('ALWAYS')
      }
    }
    archiveXUnit {
      jUnit {
        pattern('${TESTRESULTS_DIR}/${BUILD_TIMESTAMP}-build-${BUILD_NUMBER}-${CI_PUBLISH_NAME}-testing_*/TEST-*.xml')
        failIfNotNew(false)
      }
      failedThresholds {
        unstable(9999)
        unstableNew(9999)
        failure(0)
        failureNew(0)
      }
      skippedThresholds {
        unstable(9999)
        unstableNew(9999)
        failure(9999)
        failureNew(9999)
      }
      thresholdMode(ThresholdMode.NUMBER)
      timeMargin(3000)
    }
    groovyPostBuild('def run = Thread.currentThread().executable\n\
def en = run.getEnvironment()\n\
if (en["GIT_BRANCH"] != "")\n\
  manager.addShortText(en["GIT_BRANCH"])', Behavior.DoNothing)

    irc {
      channel('#ostroproject', '', true)
      notificationMessage('SummaryOnly')
      strategy('ALL')
    }
  }
}

// 4. master (combined repo) job
freeStyleJob("ostro-os_master") {
  label("master")
  description("Automatically generated. Ostro OS product master job. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(499)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  properties {
    rebuild {
      autoRebuild(false)
      rebuildDisabled(true)
    }
  }
  disabled(DISABLE_JOBS.toBoolean())
  wrappers {
    sshAgent('github-auth-ssh')
    timestamps()
  }
  environmentVariables {
    propertiesFile('${HOME}/ci/conf/configuration')
    env('CI_PUBLISH_NAME', "ostro-os")
    env('CI_COMMIT_BUILDHISTORY', "defined")
    env('CI_ARCHIVER_MODE', "defined")
    env('CI_COMMIT_PRSERVER', "defined")
    env('CI_POPULATE_SSTATE', "defined")
    env('CI_CREATE_GIT_ARCHIVE', "defined")
    keepSystemVariables(true)
    keepBuildVariables(true)
  }
  scm {
    git {
      remote {
        github(github_org+"/ostro-os", protocol="ssh")
        credentials('github-auth-ssh')
        name("origin")
        refspec("+refs/heads/*:refs/remotes/origin/*")
      }
      extensions {
        cloneOptions {
          timeout(30)
          reference("/srv/git_mirror/ostro-os.git")
        }
      }
      branches("refs/heads/master")
    }
  }
  triggers {
    scm("${scm_poll}")
  }
  steps {
    shell('${HOME}/ci/bin/build-prepare-master.sh .')
    downstreamParameterized {
      trigger('build-prepare') {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    downstreamParameterized {
      trigger('build-recipe-selftests') {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    downstreamParameterized {
      trigger("${build_targets}") {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    shell('${HOME}/ci/bin/prepare-testinfo.sh')
    downstreamParameterized {
      trigger("build-populate-sstate") {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    downstreamParameterized {
      trigger("${test_targets}") {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
        parameterFactories {
          forMatchingFiles('*.testruns.csv', 'testinfo.csv')
        }
      }
    }
    shell('${HOME}/ci/bin/fetch-testresults-into-workspace.sh')
    downstreamParameterized {
      trigger('build-finalize') {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
    downstreamParameterized {
      trigger('build-publish-images,build-publish-sources,build-publish-sstate') {
        parameters {
          propertiesFile('env.properties')
        }
      }
    }
  }
  publishers {
    archiveXUnit {
      jUnit {
        pattern('${TESTRESULTS_DIR}/${BUILD_TIMESTAMP}-build-${BUILD_NUMBER}-${CI_PUBLISH_NAME}-testing_*/TEST-*.xml')
        failIfNotNew(false)
      }
      failedThresholds {
        unstable(9999)
        unstableNew(9999)
        failure(0)
        failureNew(0)
      }
      skippedThresholds {
        unstable(9999)
        unstableNew(9999)
        failure(9999)
        failureNew(9999)
      }
      thresholdMode(ThresholdMode.NUMBER)
      timeMargin(3000)
    }
    archiveArtifacts('.ci-testresults/**')
    groovyPostBuild('def run = Thread.currentThread().executable\n\
def en = run.getEnvironment()\n\
if (en["GIT_COMMIT"] != "")\n\
  manager.addShortText(en["GIT_COMMIT"])', Behavior.DoNothing)

    downstreamParameterized {
      trigger('build-post,build-publish-buildhistory') {
        parameters {
          propertiesFile('env.properties')
        }
        condition('ALWAYS')
      }
    }
    irc {
      channel('#ostroproject', '', true)
      //notifyScmCommitters()
      //notifyScmCulprits()
      notifyUpstreamCommitters(false)
      //notifyScmFixers()
      strategy('ALL')
      notificationMessage('SummaryOnly')
    }
  }
}

// 5. retest existing images without build step
freeStyleJob('tester-re-test-existing-build') {
  label("master")
  description("Automatically generated. Manually started job to retest existing images without build phase")
  logRotator {
    daysToKeep(-1)
    numToKeep(99)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  parameters {
    stringParam('CI_BUILD_ID', '2015-07-16_16-23-03-build-137', 'From which existing build the images should come from')
  }
  steps {
    environmentVariables {
      propertiesFile('${HOME}/ci/conf/configuration')
    }
    shell("""
# delete previous files if present in workspace
rm -f env.properties *.testruns.csv.*
# re-use saved env.properties and testruns.csv from existing build
cp \${HOME}/\${CI_EXPORT}/env.properties.\${CI_BUILD_ID} env.properties
cp \${HOME}/\${CI_EXPORT}/*.testruns.csv.\${CI_BUILD_ID} ./
""")
    downstreamParameterized {
      trigger("${test_targets}") {
        block {
          buildStepFailure('FAILURE')
          failure('FAILURE')
          unstable('UNSTABLE')
        }
        parameters {
          propertiesFile('env.properties')
        }
        parameterFactories {
          forMatchingFiles('*.testruns.csv.*', 'testinfo.csv')
        }
      }
    }
  }
}
