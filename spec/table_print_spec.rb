require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/view_processor', File.dirname(__FILE__))
require File.expand_path('../lib/view_processor/table_print', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/assembly_template', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::DtkResponse do
	@command_class    = DTK::Client::AssemblyTemplate
	data              = [{"id"=>2147507731, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147507717, "components"=>["hdp-hadoop::smoketest_hdfs", "hdp-hadoop::datanode", "hdp-hadoop::tasktracker", "hdp", "hdp-hadoop::namenode-conn", "stdlib"]}, {"node_name"=>"HADOOP-NN-JT", "node_id"=>2147507725, "components"=>["hdp-hadoop::namenode", "hdp", "stdlib", "hdp-hadoop::jobtracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-C5-HADOOP"}, {"id"=>2147506303, "nodes"=>[{"node_name"=>"HADOOP-NN-JT", "node_id"=>2147506290, "components"=>["hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}, {"node_name"=>"HADOOP-slave01", "node_id"=>2147506296, "components"=>["hdp-hadoop::namenode-conn", "hdp-hadoop::datanode", "hdp", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HADOOP"}, {"id"=>2147506141, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147506134, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HADOOP_slave"}, {"id"=>2147505988, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147505961, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "hdp-hbase::zk-conn", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}, {"node_name"=>"HBASE-NN-JT-HM", "node_id"=>2147505978, "components"=>["hdp-hbase::master", "hdp", "hdp-hbase::zk-conn", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}, {"node_name"=>"HBASE-ZK", "node_id"=>2147505973, "components"=>["hdp", "stdlib", "hdp-zookeeper"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HBASE"}, {"id"=>2147506008, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147505996, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "hdp-hbase::zk-conn", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HBASE_slave"}, {"id"=>2147505734, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505728, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib"]}, {"node_name"=>"HDFS-NN", "node_id"=>2147505723, "components"=>["hdp", "stdlib", "hdp-hadoop::namenode"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HDFS"}, {"id"=>2147505743, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505737, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HDFS_slave"}, {"id"=>2147505230, "nodes"=>[{"node_name"=>"HADOOP-NN-JT", "node_id"=>2147505224, "components"=>["hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}, {"node_name"=>"HADOOP-slave01", "node_id"=>2147505217, "components"=>["hdp-hadoop::datanode", "hdp", "hdp-hadoop::namenode-conn", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HADOOP"}, {"id"=>2147505240, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147505233, "components"=>["hdp-hadoop::datanode", "hdp", "hdp-hadoop::namenode-conn", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HADOOP_slave"}, {"id"=>2147505617, "nodes"=>[{"node_name"=>"HBASE-ZK", "node_id"=>2147505612, "components"=>["hdp", "stdlib", "hdp-zookeeper"]}, {"node_name"=>"HBASE-slave01", "node_id"=>2147505590, "components"=>["hdp-hadoop::namenode-conn", "hdp-hbase::zk-conn", "hdp-hadoop::datanode", "hdp", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}, {"node_name"=>"HBASE-NN-JT-HM", "node_id"=>2147505602, "components"=>["hdp-hbase::master", "hdp-hbase::zk-conn", "hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HBASE"}, {"id"=>2147505637, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147505625, "components"=>["hdp-hadoop::namenode-conn", "hdp-hbase::zk-conn", "hdp-hadoop::datanode", "hdp", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HBASE_slave"}, {"id"=>2147505200, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505194, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib"]}, {"node_name"=>"HDFS-NN", "node_id"=>2147505189, "components"=>["hdp", "stdlib", "hdp-hadoop::namenode"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HDFS"}, {"id"=>2147505356, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505350, "components"=>["hdp-hadoop::namenode-conn", "hdp-hadoop::datanode", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HDFS_slave"}, {"id"=>2147508641, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147508634, "components"=>["hdp-hadoop::tasktracker", "hdp-hadoop::datanode", "hdp-hadoop::namenode-conn", "hdp", "stdlib"]}, {"node_name"=>"HADOOP-NN-JT", "node_id"=>2147508627, "components"=>["hdp-hadoop::smoketest_hdfs", "hdp-hadoop::namenode", "hdp", "stdlib", "hdp-hadoop::jobtracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::centos_hadoop_smoke"}, {"id"=>2147508533, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147508519, "components"=>["hdp-hadoop::tasktracker", "hdp-hadoop::datanode", "hdp-hadoop::namenode-conn", "hdp", "stdlib"]}, {"node_name"=>"HADOOP-NN-JT", "node_id"=>2147508526, "components"=>["hdp-hadoop::jobtracker", "hdp-hadoop::smoketest_hdfs", "hdp-hadoop::namenode", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::hadoop_smoke"}, {"id"=>2147508831, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147508819, "components"=>["hdp-hbase::master-conn", "hdp-hadoop::datanode", "hdp-hbase::zk-conn", "hdp-hadoop::tasktracker", "hdp", "hdp-hadoop::namenode-conn", "stdlib", "hdp-hbase::regionserver"]}, {"node_name"=>"HBASE-NN-JT-HM", "node_id"=>2147508808, "components"=>["hdp-hadoop::namenode", "hdp-hadoop::smoketest_hdfs", "hdp-hbase::master", "hdp-hbase::zk-conn", "hdp", "stdlib", "hdp-hadoop::jobtracker"]}, {"node_name"=>"HBASE-ZK", "node_id"=>2147508803, "components"=>["hdp-zookeeper", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::hbase_centos_smoke"}, {"id"=>2147493292, "nodes"=>[{"node_name"=>"master", "node_id"=>2147493278, "components"=>["hdp-hadoop::namenode", "hdp-hbase::master", "hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hbase::zk-conn"]}, {"node_name"=>"slave", "node_id"=>2147493259, "components"=>["stdlib", "hdp-hadoop::namenode-conn", "hdp-hbase::regionserver", "hdp-hbase::master-conn", "hdp-hadoop::tasktracker", "hdp-hadoop::datanode", "hdp-zookeeper", "hdp"]}, {"node_name"=>"client", "node_id"=>2147493271, "components"=>["hdp-hadoop::namenode-conn", "hdp-hadoop::client", "hdp-hadoop::smoketest_hdfs", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::smoke"}]
	@render_view      = "table_print"
	@render_data_type = "ASSEMBLY_TEMPLATE"




	context "#render" do
		@command_class    = DTK::Client::AssemblyTemplate
		data              = [{"id"=>2147507731, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147507717, "components"=>["hdp-hadoop::smoketest_hdfs", "hdp-hadoop::datanode", "hdp-hadoop::tasktracker", "hdp", "hdp-hadoop::namenode-conn", "stdlib"]}, {"node_name"=>"HADOOP-NN-JT", "node_id"=>2147507725, "components"=>["hdp-hadoop::namenode", "hdp", "stdlib", "hdp-hadoop::jobtracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-C5-HADOOP"}, {"id"=>2147506303, "nodes"=>[{"node_name"=>"HADOOP-NN-JT", "node_id"=>2147506290, "components"=>["hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}, {"node_name"=>"HADOOP-slave01", "node_id"=>2147506296, "components"=>["hdp-hadoop::namenode-conn", "hdp-hadoop::datanode", "hdp", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HADOOP"}, {"id"=>2147506141, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147506134, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HADOOP_slave"}, {"id"=>2147505988, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147505961, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "hdp-hbase::zk-conn", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}, {"node_name"=>"HBASE-NN-JT-HM", "node_id"=>2147505978, "components"=>["hdp-hbase::master", "hdp", "hdp-hbase::zk-conn", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}, {"node_name"=>"HBASE-ZK", "node_id"=>2147505973, "components"=>["hdp", "stdlib", "hdp-zookeeper"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HBASE"}, {"id"=>2147506008, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147505996, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "hdp-hbase::zk-conn", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HBASE_slave"}, {"id"=>2147505734, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505728, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib"]}, {"node_name"=>"HDFS-NN", "node_id"=>2147505723, "components"=>["hdp", "stdlib", "hdp-hadoop::namenode"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HDFS"}, {"id"=>2147505743, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505737, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-CS-HDFS_slave"}, {"id"=>2147505230, "nodes"=>[{"node_name"=>"HADOOP-NN-JT", "node_id"=>2147505224, "components"=>["hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}, {"node_name"=>"HADOOP-slave01", "node_id"=>2147505217, "components"=>["hdp-hadoop::datanode", "hdp", "hdp-hadoop::namenode-conn", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HADOOP"}, {"id"=>2147505240, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147505233, "components"=>["hdp-hadoop::datanode", "hdp", "hdp-hadoop::namenode-conn", "stdlib", "hdp-hadoop::tasktracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HADOOP_slave"}, {"id"=>2147505617, "nodes"=>[{"node_name"=>"HBASE-ZK", "node_id"=>2147505612, "components"=>["hdp", "stdlib", "hdp-zookeeper"]}, {"node_name"=>"HBASE-slave01", "node_id"=>2147505590, "components"=>["hdp-hadoop::namenode-conn", "hdp-hbase::zk-conn", "hdp-hadoop::datanode", "hdp", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}, {"node_name"=>"HBASE-NN-JT-HM", "node_id"=>2147505602, "components"=>["hdp-hbase::master", "hdp-hbase::zk-conn", "hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hadoop::namenode"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HBASE"}, {"id"=>2147505637, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147505625, "components"=>["hdp-hadoop::namenode-conn", "hdp-hbase::zk-conn", "hdp-hadoop::datanode", "hdp", "stdlib", "hdp-hbase::regionserver", "hdp-hadoop::tasktracker", "hdp-hbase::master-conn"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HBASE_slave"}, {"id"=>2147505200, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505194, "components"=>["hdp-hadoop::namenode-conn", "hdp", "hdp-hadoop::datanode", "stdlib"]}, {"node_name"=>"HDFS-NN", "node_id"=>2147505189, "components"=>["hdp", "stdlib", "hdp-hadoop::namenode"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HDFS"}, {"id"=>2147505356, "nodes"=>[{"node_name"=>"HDFS-slave01", "node_id"=>2147505350, "components"=>["hdp-hadoop::namenode-conn", "hdp-hadoop::datanode", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::R8-RH-HDFS_slave"}, {"id"=>2147508641, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147508634, "components"=>["hdp-hadoop::tasktracker", "hdp-hadoop::datanode", "hdp-hadoop::namenode-conn", "hdp", "stdlib"]}, {"node_name"=>"HADOOP-NN-JT", "node_id"=>2147508627, "components"=>["hdp-hadoop::smoketest_hdfs", "hdp-hadoop::namenode", "hdp", "stdlib", "hdp-hadoop::jobtracker"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::centos_hadoop_smoke"}, {"id"=>2147508533, "nodes"=>[{"node_name"=>"HADOOP-slave01", "node_id"=>2147508519, "components"=>["hdp-hadoop::tasktracker", "hdp-hadoop::datanode", "hdp-hadoop::namenode-conn", "hdp", "stdlib"]}, {"node_name"=>"HADOOP-NN-JT", "node_id"=>2147508526, "components"=>["hdp-hadoop::jobtracker", "hdp-hadoop::smoketest_hdfs", "hdp-hadoop::namenode", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::hadoop_smoke"}, {"id"=>2147508831, "nodes"=>[{"node_name"=>"HBASE-slave01", "node_id"=>2147508819, "components"=>["hdp-hbase::master-conn", "hdp-hadoop::datanode", "hdp-hbase::zk-conn", "hdp-hadoop::tasktracker", "hdp", "hdp-hadoop::namenode-conn", "stdlib", "hdp-hbase::regionserver"]}, {"node_name"=>"HBASE-NN-JT-HM", "node_id"=>2147508808, "components"=>["hdp-hadoop::namenode", "hdp-hadoop::smoketest_hdfs", "hdp-hbase::master", "hdp-hbase::zk-conn", "hdp", "stdlib", "hdp-hadoop::jobtracker"]}, {"node_name"=>"HBASE-ZK", "node_id"=>2147508803, "components"=>["hdp-zookeeper", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::hbase_centos_smoke"}, {"id"=>2147493292, "nodes"=>[{"node_name"=>"master", "node_id"=>2147493278, "components"=>["hdp-hadoop::namenode", "hdp-hbase::master", "hdp", "stdlib", "hdp-hadoop::jobtracker", "hdp-hbase::zk-conn"]}, {"node_name"=>"slave", "node_id"=>2147493259, "components"=>["stdlib", "hdp-hadoop::namenode-conn", "hdp-hbase::regionserver", "hdp-hbase::master-conn", "hdp-hadoop::tasktracker", "hdp-hadoop::datanode", "hdp-zookeeper", "hdp"]}, {"node_name"=>"client", "node_id"=>2147493271, "components"=>["hdp-hadoop::namenode-conn", "hdp-hadoop::client", "hdp-hadoop::smoketest_hdfs", "hdp", "stdlib"]}], "execution_status"=>nil, "module_branch_id"=>2147485695, "display_name"=>"abh::smoke"}]
		@render_view      = "table_print"
		@render_data_type = "ASSEMBLY_TEMPLATE"
		@assembly_name    = "assembly_name"
		@nodes            = "nodes"
		@id               = "id"
		@components       = "components"
		@sample           = custom_assembly_template_metadata = {
            "order"           => [
              @assembly_name,
              @nodes,
              @id,
              @components
            ],
            "mapping"         => {
              "components"    => "nodes.first['components'].join(', ')",
              "nodes"         => "nodes.size",
              "assembly_name" => "display_name",
              "id"            => "dtk_id"
            }
 		}

		response = DTK::Client::DtkResponse.new(@sample, @render_data_type, nil, true)
	
		it "should contain columns #{@assembly_name}, #{@nodes}, #{@id}, #{@components} " do
      		response.inspect.should include("assembly_name")
      		response.inspect.should include("#{@nodes}")
      		response.inspect.should include("#{@id}")
      		response.inspect.should include("#{@components}")
    	end
	end
end