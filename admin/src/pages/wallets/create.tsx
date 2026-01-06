import { Create, useForm, useSelect } from "@refinedev/antd";
import { Form, Input, InputNumber, Select } from "antd";

export const WalletCreate = () => {
    const { formProps, saveButtonProps } = useForm();

    const { selectProps: userSelectProps } = useSelect({
        resource: "users",
        optionLabel: "name",
        optionValue: "id",
    });

    return (
        <Create saveButtonProps={saveButtonProps}>
            <Form {...formProps} layout="vertical">
                <Form.Item
                    label="Name"
                    name="name"
                    rules={[{ required: true, message: "Wallet name is required" }]}
                >
                    <Input />
                </Form.Item>
                <Form.Item
                    label="Initial Balance"
                    name="balance"
                    initialValue={0}
                    rules={[{ required: true, message: "Balance is required" }]}
                >
                    <InputNumber
                        style={{ width: "100%" }}
                        formatter={(value) => `Rp ${value}`.replace(/\B(?=(\d{3})+(?!\d))/g, ",")}
                        parser={(value) => value!.replace(/Rp\s?|(,*)/g, "")}
                    />
                </Form.Item>
                <Form.Item
                    label="User"
                    name="user_id"
                    rules={[{ required: true, message: "Please select a user" }]}
                >
                    <Select {...userSelectProps} placeholder="Select user" />
                </Form.Item>
            </Form>
        </Create>
    );
};
