node("master") {
    // def scm=git credentialsId: 'github-auth-https', url: 'https://github.com/ostroproject/ostro-os-xt'
    // git branch: 'refs/pull/2132/merge', credentialsId: 'github-auth-https', poll: false, url: 'https://github.com/ostroproject/ostro-os-xt'

    echo "$GITHUB_PR_COND_REF"
    echo "$GITHUB_PR_NUMBER"
    //git branch: 'refs/pull/2132/merge', credentialsId: 'github-auth-https', poll: false, url: 'https://github.com/ostroproject/ostro-os-xt'
    dir('pipeline_handover') {
        checkout([$class: 'GitSCM', 
            branches: [[name: "origin-pull/$GITHUB_PR_NUMBER/$GITHUB_PR_COND_REF"]], 
            doGenerateSubmoduleConfigurations: false,
            extensions: [], 
            submoduleCfg: [],
            userRemoteConfigs: [
                [credentialsId: "${GITHUB_AUTH}",
                name: 'origin-pull',
                refspec: "+refs/pull/$GITHUB_PR_NUMBER/*:refs/remotes/origin-pull/$GITHUB_PR_NUMBER/*",
                url: "${GITHUB_PROJECT}"]]])
    }
    load 'pipeline_handover/Jenkinsfile'
}
