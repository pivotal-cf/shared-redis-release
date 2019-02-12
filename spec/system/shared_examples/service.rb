shared_examples_for 'a service that has distinct instances' do
  it 'has distinct instances' do
    service_broker.provision_and_bind(service.name, service.plan) do |binding1|
      service_client1 = service_client_builder(binding1)
      service_client1.write('test_key', 'test_value')

      service_broker.provision_and_bind(service.name, service.plan) do |binding2|
        service_client2 = service_client_builder(binding2)
        service_client2.write('test_key', 'another_test_value')
        expect(service_client1.read('test_key')).to eq('test_value')
        expect(service_client2.read('test_key')).to eq('another_test_value')
      end
    end
  end
end

shared_examples_for 'a service that can be shared by multiple applications' do
  it 'allows two applications to share the same instance' do
    service_broker.provision_instance(service.name, service.plan) do |service_instance|
      service_broker.bind_instance(service_instance, service.name, service.plan) do |binding1|
        service_client1 = service_client_builder(binding1)
        service_client1.write('shared_test_key', 'test_value')
        expect(service_client1.read('shared_test_key')).to eq('test_value')

        service_broker.bind_instance(service_instance, service.name, service.plan) do |binding2|
          service_client2 = service_client_builder(binding2)
          expect(service_client2.read('shared_test_key')).to eq('test_value')
        end

        expect(service_client1.read('shared_test_key')).to eq('test_value')
      end
    end
  end
end

shared_examples_for 'a service which preserves data across binding and unbinding' do
  it 'preserves data across binding and unbinding' do
    service_broker.provision_instance(service.name, service.plan) do |service_instance|
      service_broker.bind_instance(service_instance, service.name, service.plan) do |binding|
        service_client_builder(binding).write('unbound_test_key', 'test_value')
      end

      service_broker.bind_instance(service_instance, service.name, service.plan) do |binding|
        expect(service_client_builder(binding).read('unbound_test_key')).to eq('test_value')
      end
    end
  end
end

shared_examples_for 'a service which preserves data when recreating the broker VM' do
  it 'preserves data when recreating vms' do
    service_broker.provision_and_bind(service.name, service.plan) do |binding|
      service_client = service_client_builder(binding)
      service_client.write('test_key', 'test_value')
      expect(service_client.read('test_key')).to eq('test_value')

      [environment.bosh_service_broker_job_name].each do |job_name|
        bosh.recreate(deployment_name, job_name)
      end

      expect(service_client.read('test_key')).to eq('test_value')
    end
  end
end

shared_examples_for 'a persistent cloud foundry service' do
  describe 'a persistent cloud foundry service' do
    it_behaves_like 'a service that has distinct instances'
    it_behaves_like 'a service that can be shared by multiple applications'
    it_behaves_like 'a service which preserves data across binding and unbinding'
    it_behaves_like 'a service which preserves data when recreating the broker VM'
  end
end