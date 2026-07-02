package com.example.app.infrastructure.adapter;

import com.example.app.domain.rule.adapter.IRiskPort;
import com.example.app.domain.rule.model.valobj.RiskLevel;
import com.example.app.infrastructure.adapter.dto.RiskReqDTO;
import com.example.app.infrastructure.adapter.dto.RiskRespDTO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestTemplate;

import javax.annotation.Resource;

/**
 * 外部风控接口的适配器：{@link IRiskPort} 的实现，真正去发 HTTP。
 * <p>
 * 职责：<b>调外部接口 + 防腐翻译</b>——把外部的 {@link RiskRespDTO} 翻译成领域值对象
 * {@link RiskLevel}。RestTemplate、外部 DTO 等技术细节全部锁死在本层。
 * <p>
 * 降级策略：未配置 URL 或调用异常时，<b>fail-open</b> 放行（返回 LOW）——这是常见的风控降级做法，
 * 真实项目可按业务改为 fail-closed。也正因如此，本工程默认（不配 URL）能开箱即跑、既有测试全绿。
 */
@Slf4j
@Component
public class RiskHttpAdapter implements IRiskPort {

    /** 外部风控服务地址；application.yml 里 risk.service.url，未配置时降级放行 */
    @Value("${risk.service.url:}")
    private String riskServiceUrl;

    @Resource
    private RestTemplate restTemplate;

    @Override
    public RiskLevel evaluate(String userId, int age) {
        if (!StringUtils.hasText(riskServiceUrl)) {
            log.warn("[RISK] 未配置 risk.service.url，降级放行 userId={}", userId);
            return RiskLevel.LOW;
        }
        try {
            RiskReqDTO req = new RiskReqDTO(userId, age);
            RiskRespDTO resp = restTemplate.postForObject(riskServiceUrl, req, RiskRespDTO.class);
            log.info("[RISK] 外部风控返回 userId={} resp={}", userId, resp);
            // 防腐：外部字段 -> 领域值对象
            if (resp != null && "HIGH".equalsIgnoreCase(resp.getRiskLevel())) {
                return RiskLevel.HIGH;
            }
            return RiskLevel.LOW;
        } catch (Exception e) {
            log.warn("[RISK] 外部风控调用失败，降级放行 userId={}", userId, e);
            return RiskLevel.LOW;
        }
    }
}
