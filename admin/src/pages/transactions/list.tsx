import {
    List,
    useTable,
    EditButton,
    ShowButton,
    DeleteButton,
} from "@refinedev/antd";
import { Table, Space, Tag } from "antd";

export const TransactionList = () => {
    const { tableProps } = useTable({
        syncWithLocation: true,
    });

    return (
        <List>
            <Table {...tableProps} rowKey="id">
                <Table.Column dataIndex="id" title="ID" sorter />
                <Table.Column dataIndex="description" title="Description" />
                <Table.Column
                    dataIndex="type"
                    title="Type"
                    render={(value) => (
                        <Tag color={value === "income" ? "green" : "red"}>
                            {value === "income" ? "Income" : "Expense"}
                        </Tag>
                    )}
                />
                <Table.Column
                    dataIndex="amount"
                    title="Amount"
                    sorter
                    render={(value, record: { type: string }) => (
                        <span style={{ color: record.type === "income" ? "#52c41a" : "#f5222d" }}>
                            {record.type === "income" ? "+" : "-"} Rp {Number(value).toLocaleString("id-ID")}
                        </span>
                    )}
                />
                <Table.Column
                    dataIndex={["wallet", "name"]}
                    title="Wallet"
                    render={(value) => value || "-"}
                />
                <Table.Column
                    dataIndex="date"
                    title="Date"
                    sorter
                    render={(value) => value ? new Date(value).toLocaleDateString() : "-"}
                />
                <Table.Column
                    title="Actions"
                    render={(_, record: { id: number }) => (
                        <Space>
                            <EditButton hideText size="small" recordItemId={record.id} />
                            <ShowButton hideText size="small" recordItemId={record.id} />
                            <DeleteButton hideText size="small" recordItemId={record.id} />
                        </Space>
                    )}
                />
            </Table>
        </List>
    );
};
