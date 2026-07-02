package com.example.app.trigger.task;

import com.example.app.application.order.IOrderStatQuery;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import javax.annotation.Resource;

/**
 * 定时任务触发器：周期性统计订单量（示意"对账/监控"类任务）。
 * <p>同样只做"触发"，读数据走 application 查询用例 {@link IOrderStatQuery}，
 * <b>不直接依赖 infrastructure</b>（否则会被 ArchUnit 的 trigger→infra 守卫拦下）。
 * <p>由 {@code Application} 上的 {@code @EnableScheduling} 开启。
 */
@Slf4j
@Component
public class OrderStatTask {

    @Resource
    private IOrderStatQuery orderStatQuery;

    /** 启动 10s 后开始，每 15s 统计一次 */
    @Scheduled(initialDelay = 10_000, fixedRate = 15_000)
    public void reportOrderStat() {
        long total = orderStatQuery.totalOrders();
        log.info("[TASK] 当前订单总数：{}", total);
    }
}
