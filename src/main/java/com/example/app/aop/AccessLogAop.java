package com.example.app.aop;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.stereotype.Component;

/**
 * 全局切面示例（对应原 app 模块的 aop）：统一记录 trigger 层入口耗时。
 * 横切关注点集中在启动/装配层，不散落进领域代码。
 */
@Slf4j
@Aspect
@Component
public class AccessLogAop {

    @Pointcut("execution(* com.example.app.trigger..*(..))")
    public void triggerPoint() {
    }

    @Around("triggerPoint()")
    public Object around(ProceedingJoinPoint jp) throws Throwable {
        long start = System.currentTimeMillis();
        String signature = jp.getSignature().toShortString();
        try {
            return jp.proceed();
        } finally {
            log.info("[AOP] {} 耗时 {}ms", signature, System.currentTimeMillis() - start);
        }
    }
}
