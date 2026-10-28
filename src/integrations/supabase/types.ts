export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      employees: {
        Row: {
          account_no: string | null
          allowances: number
          bank_name: string | null
          base_salary: number
          created_at: string
          department: string
          employee_no: string
          full_name: string
          hired_on: string
          id: string
          nssf_no: string | null
          phone: string | null
          position: string
          status: string
        }
        Insert: {
          account_no?: string | null
          allowances?: number
          bank_name?: string | null
          base_salary?: number
          created_at?: string
          department: string
          employee_no: string
          full_name: string
          hired_on?: string
          id?: string
          nssf_no?: string | null
          phone?: string | null
          position: string
          status?: string
        }
        Update: {
          account_no?: string | null
          allowances?: number
          bank_name?: string | null
          base_salary?: number
          created_at?: string
          department?: string
          employee_no?: string
          full_name?: string
          hired_on?: string
          id?: string
          nssf_no?: string | null
          phone?: string | null
          position?: string
          status?: string
        }
        Relationships: []
      }
      finance_audit: {
        Row: {
          action: string
          actor: string
          created_at: string
          id: string
          new_value: Json | null
          old_value: Json | null
          reason: string
          record_id: string | null
        }
        Insert: {
          action: string
          actor: string
          created_at?: string
          id?: string
          new_value?: Json | null
          old_value?: Json | null
          reason: string
          record_id?: string | null
        }
        Update: {
          action?: string
          actor?: string
          created_at?: string
          id?: string
          new_value?: Json | null
          old_value?: Json | null
          reason?: string
          record_id?: string | null
        }
        Relationships: []
      }
      finance_members: {
        Row: {
          created_at: string
          email: string
          role: string
          user_id: string
        }
        Insert: {
          created_at?: string
          email?: string
          role?: string
          user_id: string
        }
        Update: {
          created_at?: string
          email?: string
          role?: string
          user_id?: string
        }
        Relationships: []
      }
      finance_records: {
        Row: {
          assigned_to: string | null
          created_at: string
          created_by: string
          data: Json
          id: string
          kind: string
          updated_at: string
        }
        Insert: {
          assigned_to?: string | null
          created_at?: string
          created_by?: string
          data?: Json
          id?: string
          kind: string
          updated_at?: string
        }
        Update: {
          assigned_to?: string | null
          created_at?: string
          created_by?: string
          data?: Json
          id?: string
          kind?: string
          updated_at?: string
        }
        Relationships: []
      }
      payroll_runs: {
        Row: {
          created_at: string
          created_by: string
          id: string
          period: string
          status: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          id?: string
          period: string
          status?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          period?: string
          status?: string
        }
        Relationships: []
      }
      payslips: {
        Row: {
          created_at: string
          employee_id: string
          gross: number
          id: string
          net: number
          nssf_employee: number
          nssf_employer: number
          paye: number
          run_id: string
        }
        Insert: {
          created_at?: string
          employee_id: string
          gross: number
          id?: string
          net: number
          nssf_employee: number
          nssf_employer: number
          paye: number
          run_id: string
        }
        Update: {
          created_at?: string
          employee_id?: string
          gross?: number
          id?: string
          net?: number
          nssf_employee?: number
          nssf_employer?: number
          paye?: number
          run_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payslips_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payslips_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "payroll_runs"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      finance_action: {
        Args: {
          p_account?: string
          p_action: string
          p_amount?: number
          p_id: string
          p_rate?: number
          p_rate_date?: string
          p_reason: string
          p_reference?: string
          p_source?: string
        }
        Returns: undefined
      }
      finance_grant: {
        Args: { p_email: string; p_role: string }
        Returns: undefined
      }
      finance_role: { Args: never; Returns: string }
      finance_save: {
        Args: { p_data: Json; p_id?: string; p_kind: string; p_reason?: string }
        Returns: string
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_staff: { Args: { _user_id: string }; Returns: boolean }
    }
    Enums: {
      app_role: "admin" | "hr"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "hr"],
    },
  },
} as const
