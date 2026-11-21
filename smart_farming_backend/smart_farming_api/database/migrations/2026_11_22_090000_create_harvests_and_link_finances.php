<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('harvests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('planting_id')->constrained()->cascadeOnDelete();
            $table->date('harvest_date');
            $table->decimal('quantity_kg', 12, 2);
            $table->decimal('sold_kg', 12, 2)->default(0);
            $table->decimal('price_per_kg', 15, 2)->nullable();
            $table->foreignId('recorded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['company_id', 'planting_id']);
        });

        Schema::table('finances', function (Blueprint $table) {
            $table->string('category', 30)->default('lainnya')->after('type');
            $table->foreignId('harvest_id')->nullable()->after('planting_id')->constrained('harvests')->nullOnDelete();
            $table->foreignId('payroll_id')->nullable()->after('harvest_id')->constrained('payrolls')->nullOnDelete();
            $table->index(['company_id', 'planting_id', 'type']);
        });

        Schema::table('plantings', function (Blueprint $table) {
            $table->date('closed_at')->nullable()->after('status');
        });

        DB::table('plantings')
            ->where('status', '!=', 'berjalan')
            ->update(['closed_at' => DB::raw('DATE(updated_at)')]);

        DB::table('finances')
            ->where('type', 'pengeluaran')
            ->where('description', 'like', 'Pengeluaran bahan%')
            ->update(['category' => 'bahan']);

        DB::table('finances')
            ->where('type', 'pemasukan')
            ->update(['category' => 'lainnya']);

        foreach (DB::table('plantings')->pluck('id') as $plantingId) {
            $total = DB::table('finances')
                ->where('planting_id', $plantingId)
                ->where('type', 'pengeluaran')
                ->sum('amount');

            DB::table('plantings')->where('id', $plantingId)->update(['total_cost' => $total]);
        }
    }

    public function down(): void
    {
        Schema::table('plantings', function (Blueprint $table) {
            $table->dropColumn('closed_at');
        });

        Schema::table('finances', function (Blueprint $table) {
            $table->dropIndex(['company_id', 'planting_id', 'type']);
            $table->dropConstrainedForeignId('payroll_id');
            $table->dropConstrainedForeignId('harvest_id');
            $table->dropColumn('category');
        });

        Schema::dropIfExists('harvests');
    }
};
