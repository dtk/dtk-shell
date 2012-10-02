#TODO: should haev separet file sfor each template
require 'erubis'
class DTK::Client::JenkinsClient
  module ConfigXML
    #TODO: this is not working now
    def self.generate_service_module_project(repo_url,module_id,branch)
      #TODO: not using branch argument
      #TODO: did not put in module_id yet
      template_bindings = {
        :repo_url => repo_url
      }
      ConfigXMLTemplateServiceModule.result(template_bindings)
    end
    def self.generate_assembly_project(assembly_id)
      #TODO: not using branch argument
      #TODO: did not put in module_id yet
      template_bindings = {
        :assembly_id => assembly_id
      }
      ConfigXMLTemplateAssembly.result(template_bindings)
    end

ConfigXMLTemplateServiceModule = Erubis::Eruby.new <<eos
<?xml version='1.0' encoding='UTF-8'?>
<project>
  <actions/>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <com.gmail.ikeike443.PlayAutoTestJobProperty/>
  </properties>
  <scm class="hudson.plugins.git.GitSCM">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <name></name>
        <refspec></refspec>
        <url><%= repo_url %></url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>**</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
    <disableSubmodules>false</disableSubmodules>
    <recursiveSubmodules>false</recursiveSubmodules>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <authorOrCommitter>false</authorOrCommitter>
    <clean>false</clean>
    <wipeOutWorkspace>false</wipeOutWorkspace>
    <pruneBranches>false</pruneBranches>
    <remotePoll>false</remotePoll>
    <ignoreNotifyCommit>false</ignoreNotifyCommit>
    <buildChooser class="hudson.plugins.git.util.DefaultBuildChooser"/>
    <gitTool>Default</gitTool>
    <submoduleCfg class="list"/>
    <relativeTargetDir></relativeTargetDir>
    <reference></reference>
    <excludedRegions></excludedRegions>
    <excludedUsers></excludedUsers>
    <gitConfigName></gitConfigName>
    <gitConfigEmail></gitConfigEmail>
    <skipTag>false</skipTag>
    <includedRegions></includedRegions>
    <scmName></scmName>
 </scm>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers class="vector"/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>ruby /var/lib/jenkins/r8_e2e.rb</command>
    </hudson.tasks.Shell>
  </builders>
    <publishers>
    <hudson.plugins.emailext.ExtendedEmailPublisher>
      <recipientList>$DEFAULT_RECIPIENTS</recipientList>
      <configuredTriggers>
        <hudson.plugins.emailext.plugins.trigger.FailureTrigger>
          <email>
            <recipientList></recipientList>
            <subject>$PROJECT_DEFAULT_SUBJECT</subject>
            <body>$PROJECT_DEFAULT_CONTENT</body>
            <sendToDevelopers>true</sendToDevelopers>
            <sendToRequester>false</sendToRequester>
            <includeCulprits>false</includeCulprits>
            <sendToRecipientList>true</sendToRecipientList>
          </email>
        </hudson.plugins.emailext.plugins.trigger.FailureTrigger>
        <hudson.plugins.emailext.plugins.trigger.StillFailingTrigger>
          <email>
            <recipientList></recipientList>
            <subject>$PROJECT_DEFAULT_SUBJECT</subject>
            <body>$PROJECT_DEFAULT_CONTENT</body>
            <sendToDevelopers>true</sendToDevelopers>
            <sendToRequester>false</sendToRequester>
            <includeCulprits>false</includeCulprits>
            <sendToRecipientList>false</sendToRecipientList>
          </email>
        </hudson.plugins.emailext.plugins.trigger.StillFailingTrigger>
        <hudson.plugins.emailext.plugins.trigger.FixedTrigger>
          <email>
            <recipientList></recipientList>
            <subject>$PROJECT_DEFAULT_SUBJECT</subject>
            <body>$PROJECT_DEFAULT_CONTENT</body>
            <sendToDevelopers>true</sendToDevelopers>
            <sendToRequester>false</sendToRequester>
            <includeCulprits>false</includeCulprits>
            <sendToRecipientList>true</sendToRecipientList>
          </email>
        </hudson.plugins.emailext.plugins.trigger.FixedTrigger>
      </configuredTriggers>
      <contentType>default</contentType>
      <defaultSubject>$DEFAULT_SUBJECT</defaultSubject>
      <defaultContent>${JELLY_SCRIPT,template=&quot;html&quot;}</defaultContent>
      <attachmentsPattern></attachmentsPattern>
    </hudson.plugins.emailext.ExtendedEmailPublisher>
  </publishers>
  <buildWrappers/>
</project>
eos


ConfigXMLTemplateAssembly = Erubis::Eruby.new <<eos
<?xml version='1.0' encoding='UTF-8'?>
<project>
  <actions/>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <com.gmail.ikeike443.PlayAutoTestJobProperty/>
  </properties>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers class="vector"/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>#!/usr/bin/env ruby

require &apos;rubygems&apos;
require &apos;rest_client&apos;
require &apos;pp&apos;
require &apos;json&apos;

STDOUT.sync = true

ENDPOINT = &apos;http://ec2-54-247-191-95.eu-west-1.compute.amazonaws.com:7000&apos;
ASSEMBLY_ID = &apos;<%= assembly_id %>&apos;

# controling &apos;pretty-print&apos; in log file
JSON_OUTPUT_ENABLED = false

# Method for deleting assembly instances
def deleteAssembly(assemblyId)
	responseAssemblyDelete = RestClient.post(ENDPOINT + &apos;/rest/assembly/delete&apos;, &apos;assembly_id&apos; =&gt; assemblyId)
	puts &quot;Assembly has been deleted! Response: #{responseAssemblyDelete}&quot;
end

#
# Method for pretty print of json responses
def json_print(json)
	pp json if JSON_OUTPUT_ENABLED
end

pp &quot;Script has been started!&quot;

puts &quot;Using template ID: #{ASSEMBLY_ID}&quot; 

# Stage the assembly
stageAssembly = RestClient.post(ENDPOINT + &apos;/rest/assembly/stage&apos;, &apos;assembly_id&apos; =&gt; ASSEMBLY_ID) 
assemblyId = JSON.parse(stageAssembly)[&quot;data&quot;][&quot;assembly_id&quot;]

puts &quot;Using stage assembly ID: #{assemblyId}&quot; 

# Create a task for the cloned assembly instance
responseTask = RestClient.post(ENDPOINT + &apos;/rest/assembly/create_task&apos;, &apos;assembly_id&apos; =&gt; assemblyId)
# Extract task id
taskId = JSON.parse(responseTask)[&quot;data&quot;][&quot;task_id&quot;]
# Execute the task
puts &quot;Starting task id: #{taskId}&quot;
responseTaskExecute = RestClient.post(ENDPOINT + &apos;/rest/task/execute&apos;, &apos;task_id&apos; =&gt; taskId)

taskStatus = &apos;executing&apos;

while taskStatus.include? &apos;executing&apos;
	sleep 20
	responseTaskStatus = RestClient.post(ENDPOINT + &apos;/rest/task/status&apos;, &apos;task_id &apos;=&gt; taskId)
	taskFullResponse = JSON.parse(responseTaskStatus)
	taskStatus = taskFullResponse[&quot;data&quot;][&quot;status&quot;]
	puts &quot;Task status: #{taskStatus}&quot;
	json_print JSON.parse(responseTaskStatus)
end

if taskStatus.include? &apos;fail&apos; 
	# Print error response from the service
	puts &quot;Smoke test failed, response: &quot;
	pp taskFullResponse
	# Delete the cloned assembly&apos;s instance
	deleteAssembly(assemblyId)
	abort(&quot;Task with ID #{taskId} failed!&quot;)
else
	puts &quot;Task with ID #{taskId} success!&quot;
end


#Create a task for the smoke test
responseSmokeTest = RestClient.post(ENDPOINT + &apos;/rest/assembly/create_smoketests_task&apos;, &apos;assembly_id&apos; =&gt; assemblyId)
json_print responseSmokeTest

#Extract task id
smokeTestId = JSON.parse(responseSmokeTest)[&quot;data&quot;][&quot;task_id&quot;]
puts &quot;Created smoke test task with ID: #{smokeTestId}&quot;
#Execute the task
responseSmokeExecute = RestClient.post(ENDPOINT + &apos;/rest/task/execute&apos;, &apos;task_id&apos; =&gt; smokeTestId)

json_print JSON.parse(responseSmokeExecute)

puts &quot;Starting smoke test task with ID: #{smokeTestId}&quot;

smokeStatus = &apos;executing&apos;

while smokeStatus.include? &apos;executing&apos;
  sleep 20
  responseSmokeStatus = RestClient.post(ENDPOINT + &apos;/rest/task/status&apos;, &apos;task_id &apos;=&gt; smokeTestId)
	fullResponse = JSON.parse(responseSmokeStatus)
  smokeStatus = fullResponse[&quot;data&quot;][&quot;status&quot;]
  puts &quot;Smoke test status: #{smokeStatus}&quot;
end

if smokeStatus.include? &apos;failed&apos;
	# Delete the cloned assembly&apos;s instance
	puts &quot;Smoke test failed, response: &quot;
	pp fullResponse

	# Getting log files for failed jobs
	task_log_response = RestClient.post(ENDPOINT + &apos;/rest/task/get_logs&apos;, &apos;task_id &apos;=&gt; smokeTestId)
	puts &quot;Logs response:&quot;	
	pp JSON.parse(task_log_response)

	deleteAssembly(assemblyId)
	abort(&quot;Smoke test failed.&quot;) 
end

# Delete the cloned assembly&apos;s instance, this is the must!
#deleteAssembly(assemblyId)

#abort(&quot;Testing failure mail report.&quot;)
</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.Mailer>
      <recipients>r8-jenkins@atlantbh.com</recipients>
      <dontNotifyEveryUnstableBuild>false</dontNotifyEveryUnstableBuild>
      <sendToIndividuals>false</sendToIndividuals>
    </hudson.tasks.Mailer>
  </publishers>
  <buildWrappers/>
</project>
eos

  end
end
