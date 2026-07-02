package com.example.app.types;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 通用常量与响应码。被各层引用。
 */
public class Constants {

    @Getter
    @AllArgsConstructor
    public enum ResponseCode {
        SUCCESS("0000", "成功"),
        UN_ERROR("0001", "未知失败"),
        ILLEGAL_PARAMETER("0002", "非法参数"),
        RULE_REJECT("1001", "规则拒绝下单");

        private final String code;
        private final String info;
    }
}
