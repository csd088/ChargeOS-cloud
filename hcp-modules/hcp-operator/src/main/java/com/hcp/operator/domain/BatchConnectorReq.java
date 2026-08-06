package com.hcp.operator.domain;

import lombok.Data;

/**
 * 批量新增中电联充电接口(connector)请求
 *
 * @author hcp
 * @date 2026-08-06
 */
@Data
public class BatchConnectorReq
{
    /** 充电设备编号(equipment_id) */
    private String equipmentId;

    /** 枪口数量 */
    private Integer gunCount;
}
