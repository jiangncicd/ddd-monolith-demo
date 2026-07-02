package com.example.app.types;

import lombok.Getter;

/**
 * 业务异常：携带响应码，供全局异常处理翻译成统一 {@link Response}。
 * <p>领域/应用层遇到"业务上不该继续"的情况可抛它，由 trigger 层的 GlobalExceptionHandler 兜底转换。
 */
@Getter
public class AppException extends RuntimeException {

    private final String code;

    public AppException(Constants.ResponseCode responseCode) {
        super(responseCode.getInfo());
        this.code = responseCode.getCode();
    }

    public AppException(Constants.ResponseCode responseCode, String info) {
        super(info);
        this.code = responseCode.getCode();
    }

    public AppException(String code, String info) {
        super(info);
        this.code = code;
    }
}
