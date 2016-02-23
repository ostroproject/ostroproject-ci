//
// DSL script to generate test jobs
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

// First of all, let's make sure that all needed plugins installed:
def install_plugins = ['copy-to-slave', 'build-with-parameters',
'buildtriggerbadge', 'copyartifact', 'delivery-pipeline-plugin', 'envinject',
'extended-read-permission', 'github-pullrequest', 'global-post-script',
'groovy-postbuild', 'jobConfigHistory', 'next-build-number', 'parameterized-trigger',
'port-allocator', 'promoted-builds', 'pollscm', 'timestamper', 'xunit','build-blocker-plugin',
'workflow-aggregator', 'workflow-cps' ]

println("Checking plugins")
updc = Jenkins.instance.getUpdateCenter()
install_plugins.each { it ->
    p=updc.getPlugin(it)
    if (p.installed) {
        println("$it already installed")
    } else {
        println("Installing $it")
        p.deploy()
    }
    deps = p.getNeededDependencies()
    if (deps) {
        deps.each { dep ->
            println("Installing dependency ")
            dep.deploy()
        }
    }
}

if (Jenkins.instance.updateCenter.isRestartRequiredForCompletion()) {
    println("Jenkins needed to be restarted!")
    Jenkins.instance.safeRestart()
}


def credentials_github_ssh = "github-auth-ssh";
def credentials_github_https = "github-auth-https";
def scm_poll = 'H/15 * * * *';
def this_job_name = "ci_seed_initial"

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
def main_repo_name = "ostro-os"
def main_repo_branch = "master"
def main_repo = github_org+"/"+main_repo_name


// Deploy our scripts to jenkins master
freeStyleJob("ci_deploy_scripts") {
    label("master")
    description("Automatically generated. Deploy CI scripts to Master")
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        blocksInheritance()
    }
    scm {
        git {
            remote {
                github(github_private+"/ostroproject-ci", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
        }
    }
    blockOn(this_job_name) {
        blockLevel('GLOBAL')
        scanQueueFor('ALL')
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        shell('rsync -avHE --delete . ${HOME}/ci/')
    }
}

// Create a seed job that generates toplevel jobs
freeStyleJob("ci_seed_job_toplevel") {
    label("master")
    description("Automatically generated DSL seed job: creates toplevel jobs")
    parameters {
        booleanParam('DISABLE_JOBS', false, 'For safety, can disable generated jobs, default:no disable')
    }
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        blocksInheritance()
    }
    multiscm {
        git {
            remote {
                github(github_private+"/ostroproject-ci", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
            extensions {
              relativeTargetDirectory("ostroproject-ci")
            }
        }
        git {
            remote {
                github(main_repo, protocol="https")
                credentials(credentials_github_https)
            }
            branches(main_repo_branch)
            extensions {
              relativeTargetDirectory(main_repo_name)
              cloneOptions {
                reference("/srv/git_mirror/${main_repo_name}.git")
              }
            }
        }
    }
    blockOn(this_job_name) {
        blockLevel('GLOBAL')
        scanQueueFor('ALL')
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        dsl {
            external('ostroproject-ci/job-config/dsl_seed_toplevel.groovy')
            additionalClasspath('ostroproject-ci/job-config/libs/*.jar')
            removeAction('DISABLE')
        }
    }
}

// Create a seed job that generates builder jobs
freeStyleJob("ci_seed_job_build") {
    label("master")
    description("Automatically generated DSL seed job: creates builder jobs")
    parameters {
        booleanParam('DISABLE_JOBS', false, 'For safety, can disable generated jobs, default:no disable')
    }
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        blocksInheritance()
    }
    scm {
        git {
            remote {
                github(github_private+"/ostroproject-ci", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
        }
    }
    blockOn(this_job_name) {
        blockLevel('GLOBAL')
        scanQueueFor('ALL')
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        dsl {
            external('job-config/dsl_seed_builder.groovy')
            removeAction('DISABLE')
        }
    }
}

// Create a seed job that generates tester jobs
freeStyleJob("ci_seed_job_test") {
    label("master")
    description("Automatically generated DSL seed job: creates tester jobs")
    parameters {
        booleanParam('DISABLE_JOBS', false, 'For safety, can disable generated jobs, default:no disable')
    }
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        blocksInheritance()
    }
    scm {
        git {
            remote {
                github(github_private+"/ostroproject-ci", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
        }
    }
    blockOn(this_job_name) {
        blockLevel('GLOBAL')
        scanQueueFor('ALL')
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        dsl {
            external('job-config/dsl_seed_tester.groovy')
            removeAction('DISABLE')
        }
    }
}

// cleanup job on coordinator
freeStyleJob('ci_cleanup_coordinator') {
  label("coordinator")
  description("Automatically generated. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(50)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  configure { project ->
    project / 'buildWrappers' / 'com.michelin.cio.hudson.plugins.copytoslave.CopyToSlaveBuildWrapper' {
      includes('ci/bin/cleanup-old-builds.sh,ci/conf/deletion-policy')
      excludes('')
      flatten('false')
      includeAntExcludes('false')
      hudsonHomeRelative('false')
      relativeTo('somewhereElse')
    }
  }
  wrappers {
      timestamps()
  }
  triggers {
      cron("H 3 * * *")
  }
  steps {
    environmentVariables {
      propertiesFile('ci/conf/deletion-policy')
    }
    shell('ci/bin/cleanup-old-builds.sh')
  }
}

// cleanup job on master
freeStyleJob('ci_cleanup_master') {
  label("master")
  description("Automatically generated. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(50)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  wrappers {
      timestamps()
  }
  triggers {
      cron("H 3 * * *")
  }
  steps {
    environmentVariables {
      propertiesFile('${HOME}/ci/conf/configuration')
    }
    shell('${HOME}/ci/bin/cleanup-master-cache.sh')
  }
}

// cleanup job on worker
freeStyleJob('ci_cleanup_worker') {
  label("ostro-builder")
  description("Automatically generated. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(50)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  configure { project ->
    project / 'buildWrappers' / 'com.michelin.cio.hudson.plugins.copytoslave.CopyToSlaveBuildWrapper' {
      includes('ci/conf/configuration,ci/bin/cleanup-worker.sh')
      excludes('')
      flatten('false')
      includeAntExcludes('false')
      hudsonHomeRelative('false')
      relativeTo('somewhereElse')
    }
  }
  wrappers {
      timestamps()
  }
  // deals with sstate area used by main PR job, so better not to run at same time
  blockOn('ostro-os_pull-requests') {
      blockLevel('GLOBAL')
      scanQueueFor('ALL')
  }
  triggers {
      cron("H 4 * * *")
  }
  steps {
    environmentVariables {
      propertiesFile('ci/conf/configuration')
    }
    shell('ci/bin/cleanup-worker.sh')
  }
}

// swupdate links maintenance job on ext.download server
freeStyleJob('ci_maintain_download_swupd_links') {
  label("download")
  description("Automatically generated. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(50)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  configure { project ->
    project / 'buildWrappers' / 'com.michelin.cio.hudson.plugins.copytoslave.CopyToSlaveBuildWrapper' {
      includes('ci/bin/maintain-swupd-links.sh')
      excludes('')
      flatten('false')
      includeAntExcludes('false')
      hudsonHomeRelative('false')
      relativeTo('somewhereElse')
    }
  }
  triggers {
      upstream('ostro-os_master', 'SUCCESS')
  }
  blockOn('build-publish-images') {
      blockLevel('GLOBAL')
      scanQueueFor('ALL')
  }
  steps {
    shell('ci/bin/maintain-swupd-links.sh')
  }
}


// swupdate links maintenance job on workers-coordinator server
freeStyleJob('ci_maintain_coordinator_swupd_links') {
  label("coordinator")
  description("Automatically generated. Manual changes will be overriden by next seed job run.")
  logRotator {
    daysToKeep(-1)
    numToKeep(50)
    artifactDaysToKeep(-1)
    artifactNumToKeep(-1)
  }
  configure { project ->
    project / 'buildWrappers' / 'com.michelin.cio.hudson.plugins.copytoslave.CopyToSlaveBuildWrapper' {
      includes('ci/bin/maintain-swupd-links.sh')
      excludes('')
      flatten('false')
      includeAntExcludes('false')
      hudsonHomeRelative('false')
      relativeTo('somewhereElse')
    }
  }
  triggers {
      upstream('ostro-os_master', 'SUCCESS')
  }
  steps {
    shell('ci/bin/maintain-swupd-links.sh')
  }
}

// Seed upstream-monitor jobs
freeStyleJob("ci_seed_job_upstream_monitor") {
    label("master")
    description("Automatically generated. DSL seed job: creates upsreat-monitor job.\nList of layers comes from main ostro-os repository")
    parameters {
        booleanParam('DISABLE_JOBS', ostro_ci_server == "production" ? false : true, 'For safety, can disable generated jobs, default:no disable')
        stringParam('MAIN_REPO', main_repo, 'org/name github format for main repo')
        stringParam('MAIN_REPO_NAME', main_repo_name, 'name of main repo')
        stringParam('MAIN_REPO_BRANCH', main_repo_branch, 'branch for main repo')
    }
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        blocksInheritance()
    }
    multiscm {
        git {
            remote {
                github(github_private+"/ostroproject-ci", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
            relativeTargetDir("ostroproject-ci")
            extensions {
              relativeTargetDirectory("ostroproject-ci")
            }
        }
        git {
            remote {
                github(main_repo, protocol="https")
                credentials(credentials_github_https)
            }
            branches(main_repo_branch)
            extensions {
              relativeTargetDirectory(main_repo_name)
              cloneOptions{
                reference("/srv/git_mirror/${main_repo_name}.git")
              }
            }
        }
    }
    blockOn(this_job_name) {
        blockLevel('GLOBAL')
        scanQueueFor('ALL')
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        dsl {
            external('ostroproject-ci/job-config/dsl_seed_upstream_monitor.groovy')
            additionalClasspath('ostroproject-ci/job-config/libs/*.jar')
            removeAction('DISABLE')
        }
    }
}


// Publish theme to download server
freeStyleJob("ci_deploy_download_theme") {
    label("master")
    description("Automatically generated. Deploy Download theme to server")
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        permission("hudson.model.Item.Read", github_org)
        permission("hudson.model.Item.Discover", github_org)
        blocksInheritance()
    }
    scm {
        git {
            remote {
                github(github_private+"/ostro-download-theme", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
        }
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        if (ostro_ci_server == "production") {
            shell('perl -pe \'s#/_(stg-)?theme/#/_theme/#g\' -i *.html')
            shell('perl -pe \'s#https?://(stg.)?ostroproject.org/#https://ostroproject.org/#g\' -i *.html')
            shell('rsync -avcHE --delete --exclude=.git . rsync://osdownload.vlan14/theme_RW_ostro/')
        }
        if (ostro_ci_server == "staging") {
            shell('perl -pe \'s#/_(stg-)?theme/#/_stg-theme/#g\' -i *.html')
            shell('perl -pe \'s#https?://(stg.)?ostroproject.org/#https://stg.ostroproject.org/#g\' -i *.html')
            shell('rsync -avcHE --delete --exclude=.git . rsync://osdownload.vlan14/stg_theme_RW_ostro/')
        }
    }
}


// Publish docs
freeStyleJob("ci_deploy_documentation") {
    label("master")
    description("Automatically generated. Deploy documentation to server")
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        permission("hudson.model.Item.Read", github_org)
        permission("hudson.model.Item.Discover", github_org)
        blocksInheritance()
    }
    multiscm {
        git {
            remote {
                github(github_private+"/ostro-docs-theme", protocol="https")
                credentials(credentials_github_https)
            }
            branches("master")
            extensions {
              relativeTargetDirectory("ostro-docs-theme")
            }
        }
        git {
            remote {
                if (ostro_ci_server == "staging") {
                    github(github_org+"/meta-ostro", protocol="https")
                } else if (ostro_ci_server == "production") {
                    github(github_org+"/ostro-os", protocol="https")
                }
                credentials(credentials_github_https)
            }
            branches("master")
            extensions {
              relativeTargetDirectory("source")
            }
        }
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        shell("""
cd source/doc/sphinx_build
rm -rf _build
make SPHINXOPTS="-Dhtml_theme_path=\$WORKSPACE/ -Dhtml_theme=ostro-docs-theme" html
""")
        if (ostro_ci_server == "staging") {
            shell('rsync -avcHE --partial --delete $WORKSPACE/source/doc/sphinx_build/_build/html/ rsync://stg-sites.vlan14/ostro-docs-RW-stg-in/')
        } else if (ostro_ci_server == "production") {
            shell('rsync -avcHE --partial --delete $WORKSPACE/source/doc/sphinx_build/_build/html/ rsync://sites1.vlan14/ostro-docs-RW-in/')
        }
    }
}


// matrix job showing isafw results
matrixJob('code_isafw_reports') {
    axes {
      text('machine', 'beaglebone', 'edison', 'intel-corei7-64', 'intel-quark')
      text('checker', 'cfa', 'cve', 'fsa', 'la')
      label('label', 'coordinator')
    }
    triggers {
      upstream('ostro-os_master', 'SUCCESS')
    }
    label("master")
    description("Automatically generated matrix job. Show isafw reports")
    steps {
      shell("""
rm -fr *
_path=\${BUILD_STORAGE_BASE}/builds/ostro-os/latest
_tag=`readlink \${_path}`
echo CI_TAG=\$_tag > env.prop
_reports=\${_path}/isafw
rsync -av \${_reports}/\${machine}/\${checker}_*.xml ./
""")
      environmentVariables {
        propertiesFile('env.prop')
      }
    }
    publishers {
      archiveXUnit {
        jUnit {
          pattern('*.xml')
          failIfNotNew(false)
        }
        failedThresholds {
          unstable(99999)
          unstableNew(0)
          failure(99999)
          failureNew(99999)
        }
        skippedThresholds {
          unstable(99999)
          unstableNew(99999)
          failure(99999)
          failureNew(99999)
        }
        thresholdMode(ThresholdMode.NUMBER)
        timeMargin(3000)
      }
    groovyPostBuild('def run = Thread.currentThread().executable\n\
def en = run.getEnvironment()\n\
manager.addShortText(en["CI_TAG"])\n\
', Behavior.DoNothing)
    }
}

// Create a seed job that generates layer repo mirroring jobs
freeStyleJob("ci_seed_mirror_layers") {
    label("master")
    description("Automatically generated DSL seed job: creates layer repo mirroring jobs")
    logRotator {
      daysToKeep(-1)
      numToKeep(99)
      artifactDaysToKeep(-1)
      artifactNumToKeep(-1)
    }
    parameters {
        booleanParam('DISABLE_JOBS', false, 'For safety, can disable generated jobs, default:no disable')
    }
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        blocksInheritance()
    }
    multiscm {
        git {
            remote {
                github(github_private+"/ostroproject-ci", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
            extensions {
              relativeTargetDirectory("ostroproject-ci")
            }
        }
        git {
            remote {
                github(main_repo, protocol="https")
                credentials(credentials_github_https)
            }
            branches(main_repo_branch)
            extensions {
              relativeTargetDirectory(main_repo_name)
              cloneOptions {
                reference("/srv/git_mirror/${main_repo_name}.git")
              }
            }
        }
    }
    blockOn(this_job_name) {
        blockLevel('GLOBAL')
        scanQueueFor('ALL')
    }
    triggers {
        scm(scm_poll)
    }
    steps {
        dsl {
            external('ostroproject-ci/job-config/dsl_seed_mirror_layers.groovy')
            additionalClasspath('ostroproject-ci/job-config/libs/*.jar')
            removeAction('DISABLE')
        }
    }
}


// Create a seed job that generates Ostro OS XT Jobs
freeStyleJob("ci_seed_job_ostro-os-xt") {
    label("master")
    description("Automatically generated DSL seed job: creates toplevel jobs")
    parameters {
        booleanParam('DISABLE_JOBS', false, 'For safety, can disable generated jobs, default:no disable')
    }
    authorization {
        permissionAll("ostroproject*Ostro SCM")
        blocksInheritance()
    }
    multiscm {
        git {
            remote {
                github(github_private+"/ostroproject-ci", protocol="https")
                credentials(credentials_github_https)
            }
            branches(ostro_ci_server)
            extensions {
              relativeTargetDirectory("ostroproject-ci")
            }
        }
        git {
            remote {
                github(main_repo, protocol="https")
                credentials(credentials_github_https)
            }
            branches(main_repo_branch)
            extensions {
              relativeTargetDirectory(main_repo_name)
              cloneOptions {
                reference("/srv/git_mirror/${main_repo_name}.git")
              }
            }
        }
    }
    blockOn(this_job_name) {
        blockLevel('GLOBAL')
        scanQueueFor('ALL')
    }
    triggers {
        githubPush()
        scm(scm_poll)
    }
    steps {
        dsl {
            external('ostroproject-ci/job-config/dsl_seed_ostro_os_xt.groovy')
            // additionalClasspath('ostroproject-ci/job-config/libs/*.jar')
            removeAction('DISABLE')
        }
    }
}
