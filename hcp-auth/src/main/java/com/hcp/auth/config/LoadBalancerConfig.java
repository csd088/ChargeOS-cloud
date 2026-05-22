package com.hcp.auth.config;

import org.springframework.cloud.loadbalancer.annotation.LoadBalancerClient;
import org.springframework.cloud.loadbalancer.annotation.LoadBalancerClients;
import org.springframework.context.annotation.Configuration;

/**
 * 负载均衡器配置
 */
@Configuration
@LoadBalancerClients({
    @LoadBalancerClient(name = "hcp-system")
})
public class LoadBalancerConfig
{
}
