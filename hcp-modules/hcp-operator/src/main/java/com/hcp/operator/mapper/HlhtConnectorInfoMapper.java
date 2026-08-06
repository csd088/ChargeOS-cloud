package com.hcp.operator.mapper;

import java.util.List;
import com.hcp.operator.domain.HlhtConnectorInfo;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.hcp.common.mybatisplus.mapper.BaseMapperX;
import org.apache.ibatis.annotations.Param;
/**
 * 接口信息Mapper接口
 *
 * @author hcp
 * @date 2024-08-11
 */
public interface HlhtConnectorInfoMapper extends BaseMapperX<HlhtConnectorInfo>
{

    /**
     * 查询接口信息列表-分页
     *
     * @param hlhtConnectorInfo 接口信息
     * @return 接口信息集合
     */
    IPage<HlhtConnectorInfo> selectHlhtConnectorInfoList(Page page,@Param("query") HlhtConnectorInfo hlhtConnectorInfo);
    /**
     * 查询接口信息列表
     *
     * @param hlhtConnectorInfo 接口信息
     * @return 接口信息集合
     */
    List<HlhtConnectorInfo> selectHlhtConnectorInfoList(@Param("query") HlhtConnectorInfo hlhtConnectorInfo);

    /**
     * 批量删除接口信息
     *
     * @param connectorIds 需要删除的数据主键集合
     * @return 结果
     */
    int deleteHlhtConnectorInfoByConnectorIds(String[] connectorIds);

    /**
     * 批量新增充电接口
     *
     * @param list 接口集合
     * @return 结果
     */
    int insertBatchConnectors(@Param("list") List<HlhtConnectorInfo> list);

    /**
     * 按设备编号批量删除接口（删设备级联用）
     *
     * @param equipmentIds 设备编号集合
     * @return 结果
     */
    int deleteByEquipmentIds(@Param("equipmentIds") String[] equipmentIds);

    /**
     * 按设备编号删除接口（删设备级联用）
     *
     * @param equipmentId 设备编号
     * @return 结果
     */
    int deleteByEquipmentId(@Param("equipmentId") String equipmentId);
}
