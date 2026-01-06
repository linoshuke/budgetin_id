import { Show } from "@refinedev/antd";
import { useShow, useOne } from "@refinedev/core";
import { Typography, Tag } from "antd";

const { Title, Text } = Typography;

export const TransactionShow = () => {
    const { queryResult } = useShow();
    const { data, isLoading } = queryResult;
    const record = data?.data;

    const { data: walletData } = useOne({
        resource: "wallets",
        id: record?.wallet_id,
        queryOptions: {
            enabled: !!record?.wallet_id,
        },
    });

    return (
        <Show isLoading={isLoading}>
            <Title level={5}>ID</Title>
            <Text>{record?.id}</Text>

            <Title level={5}>Description</Title>
            <Text>{record?.description}</Text>

            <Title level={5}>Type</Title>
            <Tag color={record?.type === "income" ? "green" : "red"}>
                {record?.type === "income" ? "Income" : "Expense"}
            </Tag>

            <Title level={5}>Amount</Title>
            <Text style={{ color: record?.type === "income" ? "#52c41a" : "#f5222d" }}>
                {record?.type === "income" ? "+" : "-"} Rp {Number(record?.amount || 0).toLocaleString("id-ID")}
            </Text>

            <Title level={5}>Wallet</Title>
            <Text>{walletData?.data?.name || record?.wallet?.name || "-"}</Text>

            <Title level={5}>Category</Title>
            <Text>{record?.category || "-"}</Text>

            <Title level={5}>Date</Title>
            <Text>
                {record?.date
                    ? new Date(record.date).toLocaleDateString()
                    : "-"}
            </Text>

            <Title level={5}>Created At</Title>
            <Text>
                {record?.created_at
                    ? new Date(record.created_at).toLocaleString()
                    : "-"}
            </Text>
        </Show>
    );
};
