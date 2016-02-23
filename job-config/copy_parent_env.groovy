#!groovy
def env_file = new hudson.FilePath(build.workspace, "parent.env")
def cause = build.causes.grep({ it instanceof hudson.model.Cause.UpstreamCause })[0]
if (cause) {
	def upstream_build=jenkins.model.Jenkins.instance.getItem(cause.upstreamProject).getBuildByNumber(cause.upstreamBuild)
	parent_env = upstream_build.getEnvironment()
	env_stream = env_file.write()
	for (it in parent_env) {
	  env_stream.write(("PARENT_"+it.key+"="+it.value+"\n").bytes)
	}
} else {
	env_file.write("","utf-8")
}
