package com.hcp.operator.domain;

import lombok.Data;

/**
 * 批量新增充电桩端口请求
 *
 * @author hcp
 * @date 2026-08-06
 */
@Data
public class BatchPortReq
{
    /** 充电桩编号 */
    private String pileId;

    /** 枪口数量 */
    private Integer gunCount;
}
