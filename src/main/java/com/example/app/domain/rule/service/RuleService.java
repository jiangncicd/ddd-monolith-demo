package com.example.app.domain.rule.service;

import com.example.app.domain.rule.adapter.IRiskPort;
import com.example.app.domain.rule.model.entity.DecisionMatterEntity;
import com.example.app.domain.rule.model.entity.EngineResultEntity;
import com.example.app.domain.rule.model.valobj.RiskLevel;
import com.example.app.types.Constants;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;

/**
 * 规则领域服务：下单准入决策。
 * 这类核心业务规则留在领域服务里，不要上浮到 application 编排层。
 * （更复杂时可在本包下拆出 engine/ + logic/ 的过滤器链，参考原文的规则引擎结构。）
 */
@Slf4j
@Service
public class RuleService {

    /** 允许下单的最小年龄 */
    private static final int MIN_AGE = 18;

    /** 外部风控端口：只依赖领域接口，实现（发 HTTP）在 infrastructure */
    @Resource
    private IRiskPort riskPort;

    public EngineResultEntity process(DecisionMatterEntity matter) {
        // 规则1：本地规则——年龄
        if (matter.getAge() < MIN_AGE) {
            log.info("规则决策：用户 {} 年龄 {} < {}，拒绝下单", matter.getUserId(), matter.getAge(), MIN_AGE);
            return EngineResultEntity.builder()
                    .allow(false)
                    .code(Constants.ResponseCode.RULE_REJECT.getCode())
                    .info("年龄未满 " + MIN_AGE + " 岁，不允许下单")
                    .build();
        }

        // 规则2：外部规则——调用风控系统（经端口，领域拿到的是 RiskLevel 值对象）
        RiskLevel riskLevel = riskPort.evaluate(matter.getUserId(), matter.getAge());
        if (RiskLevel.HIGH == riskLevel) {
            log.info("规则决策：用户 {} 风控命中 HIGH，拒绝下单", matter.getUserId());
            return EngineResultEntity.builder()
                    .allow(false)
                    .code(Constants.ResponseCode.RULE_REJECT.getCode())
                    .info("风控评估为高风险，不允许下单")
                    .build();
        }

        return EngineResultEntity.builder()
                .allow(true)
                .code(Constants.ResponseCode.SUCCESS.getCode())
                .info("规则通过")
                .build();
    }
}
