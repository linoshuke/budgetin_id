import { Card, Col, Row, Statistic } from "antd";
import { useList } from "@refinedev/core";
import {
    UserOutlined,
    WalletOutlined,
    TransactionOutlined,
    DollarOutlined,
} from "@ant-design/icons";

export const Dashboard = () => {
    const { data: usersData } = useList({
        resource: "users",
        pagination: { current: 1, pageSize: 1 },
    });

    const { data: walletsData } = useList({
        resource: "wallets",
        pagination: { current: 1, pageSize: 1 },
    });

    const { data: transactionsData } = useList({
        resource: "transactions",
        pagination: { current: 1, pageSize: 1 },
    });

    return (
        <div style={{ padding: 24 }}>
            <h1>Dashboard</h1>
            <Row gutter={[16, 16]}>
                <Col xs={24} sm={12} lg={6}>
                    <Card>
                        <Statistic
                            title="Total Users"
                            value={usersData?.total ?? 0}
                            prefix={<UserOutlined />}
                            valueStyle={{ color: "#1890ff" }}
                        />
                    </Card>
                </Col>
                <Col xs={24} sm={12} lg={6}>
                    <Card>
                        <Statistic
                            title="Total Wallets"
                            value={walletsData?.total ?? 0}
                            prefix={<WalletOutlined />}
                            valueStyle={{ color: "#52c41a" }}
                        />
                    </Card>
                </Col>
                <Col xs={24} sm={12} lg={6}>
                    <Card>
                        <Statistic
                            title="Total Transactions"
                            value={transactionsData?.total ?? 0}
                            prefix={<TransactionOutlined />}
                            valueStyle={{ color: "#722ed1" }}
                        />
                    </Card>
                </Col>
                <Col xs={24} sm={12} lg={6}>
                    <Card>
                        <Statistic
                            title="Active Today"
                            value={0}
                            prefix={<DollarOutlined />}
                            valueStyle={{ color: "#fa8c16" }}
                        />
                    </Card>
                </Col>
            </Row>

            <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
                <Col span={24}>
                    <Card title="Welcome to Budgetin Admin Panel">
                        <p>
                            Manage your users, wallets, and transactions from this dashboard.
                            Use the sidebar navigation to access different sections.
                        </p>
                    </Card>
                </Col>
            </Row>
        </div>
    );
};
